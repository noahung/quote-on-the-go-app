import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { GoogleGenAI } from '@google/genai';

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Google GenAI with Firebase config
const getGenAI = () => {
  const apiKey = functions.config().googleai?.key;
  if (!apiKey) {
    throw new Error('Google AI API key not configured. Run: firebase functions:config:set googleai.key="YOUR_KEY"');
  }
  return new GoogleGenAI({ apiKey });
};

// AI Line Items Generation Function - Simple HTTP endpoint
export const generateLineItems = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // Only accept POST
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const { prompt, companyId, idToken } = req.body;

  // Verify authentication via ID token
  if (!idToken) {
    res.status(401).json({ error: 'Authentication required' });
    return;
  }

  // Verify Firebase Auth token
  let decodedToken;
  try {
    decodedToken = await admin.auth().verifyIdToken(idToken);
  } catch (e) {
    res.status(401).json({ error: 'Invalid authentication token' });
    return;
  }
  const userId = decodedToken.uid;

  // Validate input
  if (!prompt || typeof prompt !== 'string' || prompt.trim().length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Please provide a valid job description.'
    );
  }

  if (!companyId || typeof companyId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Company ID is required.'
    );
  }

  try {
    // Verify user's company access and premium status
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (!userData || userData.companyId !== companyId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You do not have access to this company.'
      );
    }

    // Check company tier
    const companyDoc = await admin.firestore().collection('companies').doc(companyId).get();
    const companyData = companyDoc.data();

    if (!companyData || companyData.tier !== 'premium') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'AI generation is only available for premium users.'
      );
    }

    // Get GenAI instance with API key
    const genAI = getGenAI();

    // Call Google GenAI API
    const model = genAI.models;
    const response = await model.generateContent({
      model: 'gemini-2.0-flash',
      contents: [{
        role: 'user',
        parts: [{
          text: `Generate a list of line items for a quotation based on this description: "${prompt}".

Return a JSON object with an "items" array.
Each item should have:
- "description" (string): Professional description of the work/material
- "itemDetails" (string, optional): Extended specifications or scope details
- "quantity" (number): Amount of units
- "unitPrice" (number): Price per unit in GBP

Guidelines:
- Keep descriptions professional and concise
- Use British English spelling (e.g. "labour", "colour", "centre")
- Assume currency is GBP
- Use realistic market rates for UK trade work
- Break down complex jobs into logical line items
- Include labour and materials as separate items when appropriate

Example output format:
{
  "items": [
    {
      "description": "Split-system air conditioning unit - 2.5kW",
      "itemDetails": "Supply and installation of wall-mounted unit including refrigerant lines",
      "quantity": 5,
      "unitPrice": 450.00
    },
    {
      "description": "Electrical labour - AC installation",
      "itemDetails": "Running power from distribution board to each unit location",
      "quantity": 5,
      "unitPrice": 180.00
    }
  ]
}`
        }]
      }],
      config: {
        temperature: 0.2,
        maxOutputTokens: 2048,
        responseMimeType: 'application/json',
      },
    });

    const responseText = response.text;

    if (!responseText) {
      throw new functions.https.HttpsError(
        'internal',
        'AI service returned empty response.'
      );
    }

    // Parse the JSON response
    let parsedResponse;
    try {
      parsedResponse = JSON.parse(responseText);
    } catch (e) {
      // Try to extract JSON from markdown code block if present
      const jsonMatch = responseText.match(/```(?:json)?\n?([\s\S]*?)```/);
      if (jsonMatch) {
        parsedResponse = JSON.parse(jsonMatch[1]);
      } else {
        throw new Error('Failed to parse AI response');
      }
    }

    const items = parsedResponse?.items || [];

    // Validate items structure
    const validatedItems = items.filter((item: any) => {
      return item &&
        typeof item.description === 'string' &&
        typeof item.quantity === 'number' &&
        typeof item.unitPrice === 'number';
    }).map((item: any) => ({
      description: item.description,
      itemDetails: item.itemDetails || '',
      quantity: Math.max(1, item.quantity),
      unitPrice: Math.max(0, item.unitPrice),
    }));

    if (validatedItems.length === 0) {
      throw new functions.https.HttpsError(
        'internal',
        'AI did not generate any valid items. Please try again with a more detailed description.'
      );
    }

    res.json({
      success: true,
      items: validatedItems,
    });
    return;

  } catch (error: any) {
    console.error('AI Generation Error:', error);

    // Handle GenAI API errors
    if (error.message?.includes('API key')) {
      res.status(500).json({ error: 'AI service configuration error' });
      return;
    }

    if (error.message?.includes('quota') || error.message?.includes('rate limit')) {
      res.status(429).json({ error: 'AI quota exceeded. Please try again later.' });
      return;
    }

    res.status(500).json({ error: 'Failed to generate items' });
  }
});

// Health check function for testing
export const healthCheck = functions.https.onCall(async (_request) => {
  return {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  };
});

// Job Status Email Notification - Called from mobile app when worker updates status
export const sendJobStatusEmail = functions.https.onCall(async (request) => {
  const { jobId, status, companyId } = request.data;
  const auth = request.auth;

  // Verify authentication
  if (!auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  if (!jobId || !status || !companyId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Job ID, status, and company ID are required.'
    );
  }

  try {
    // Get job data
    const jobDoc = await admin.firestore().collection('events').doc(jobId).get();
    if (!jobDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Job not found.');
    }

    const jobData = jobDoc.data();
    if (jobData?.companyId !== companyId) {
      throw new functions.https.HttpsError('permission-denied', 'Access denied.');
    }

    // Currently only send email for 'En Route' status (matching webapp behavior)
    // Can be extended to other statuses as needed
    if (status !== 'En Route') {
      return { success: true, message: 'Email not required for this status' };
    }

    // Get customer email
    let customerEmail = '';
    let customerName = jobData?.customerName || 'Customer';

    if (jobData?.customerId) {
      const customerDoc = await admin.firestore()
        .collection('customers')
        .doc(jobData.customerId)
        .get();
      if (customerDoc.exists) {
        const customerData = customerDoc.data();
        customerEmail = customerData?.email || '';
        if (customerData?.name) {
          customerName = customerData.name;
        }
      }
    }

    // Fallback: try to find customer by name if no customerId match
    if (!customerEmail && jobData?.customerName) {
      const customersSnap = await admin.firestore()
        .collection('customers')
        .where('companyId', '==', companyId)
        .where('name', '==', jobData.customerName)
        .limit(1)
        .get();
      if (!customersSnap.empty) {
        const customerData = customersSnap.docs[0].data();
        customerEmail = customerData?.email || '';
      }
    }

    if (!customerEmail) {
      console.log(`Could not find customer email for job ${jobId}. Email notification skipped.`);
      return { success: true, message: 'Customer email not found, notification skipped' };
    }

    // Get company info
    const companyDoc = await admin.firestore().collection('companies').doc(companyId).get();
    const companyData = companyDoc.data();
    const companyName = companyData?.name || 'Our Team';
    const companyEmail = companyData?.email || '';

    // Brevo configuration from Firebase config
    const brevoApiKey = functions.config().brevo?.key;
    if (!brevoApiKey) {
      console.error('BREVO_API_KEY not configured in Firebase Functions config');
      return { success: false, error: 'Email service not configured' };
    }

    const systemEmail = functions.config().brevo?.sender_email || 'notifications@quoteonthego.co.uk';
    const systemName = functions.config().brevo?.sender_name || 'Quote On The Go';

    const sender = { email: systemEmail, name: systemName };
    const replyTo = companyEmail ? { email: companyEmail, name: companyName } : sender;

    const subject = `🚚 We're on our way! - ${companyName}`;
    const htmlContent = `
      <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
        <h2 style="color: #f4781f;">Your crew is en route!</h2>
        <p>Hello ${customerName},</p>
        <p>We wanted to let you know that our team is currently en route to your location for your scheduled job: <strong>${jobData?.title || 'Scheduled Service'}</strong>.</p>
        ${jobData?.customerAddress ? `<p><strong>Service Location:</strong><br/>${jobData.customerAddress}</p>` : ''}
        <p>We will arrive shortly. If you need to contact us, please reply to this email.</p>
        <br/>
        <p>Regards,</p>
        <p><strong>${companyName}</strong></p>
      </div>
    `;
    const textContent = `Hello ${customerName},

We wanted to let you know that our team is currently en route to your location for your scheduled job: ${jobData?.title || 'Scheduled Service'}.
${jobData?.customerAddress ? `Service Location: ${jobData.customerAddress}` : ''}

We will arrive shortly. If you need to contact us, please reply to this email.

Regards,
${companyName}`;

    // Send email via Brevo API
    const brevoApiUrl = 'https://api.brevo.com/v3/smtp/email';
    const emailData = {
      to: [{ email: customerEmail, name: customerName }],
      sender,
      replyTo,
      subject,
      htmlContent,
      textContent,
      clickTracking: false,
      openTracking: false,
    };

    const response = await fetch(brevoApiUrl, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'api-key': brevoApiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(emailData),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Brevo API Error:', errorText);
      return { success: false, error: 'Failed to send email' };
    }

    const responseData = await response.json();
    console.log(`Job status email sent to ${customerEmail} for job ${jobId}`);

    return { success: true, messageId: responseData.messageId };

  } catch (error: any) {
    console.error('Error sending job status email:', error);
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to send email notification'
    );
  }
});
