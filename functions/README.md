# Firebase Cloud Functions - Quote On The Go

This directory contains Firebase Cloud Functions for the Quote On The Go mobile app.

## Functions

### `generateLineItems` (Callable)
Generates line items for quotations and invoices using Google GenAI (Gemini).

**Input:**
```json
{
  "prompt": "Install 5 split-system air conditioners...",
  "companyId": "company_id_here"
}
```

**Output:**
```json
{
  "success": true,
  "items": [
    {
      "description": "Split-system AC unit - 2.5kW",
      "itemDetails": "Supply and installation...",
      "quantity": 5,
      "unitPrice": 450.00
    }
  ]
}
```

**Authentication:** Requires authenticated user with premium company tier.

### `healthCheck` (Callable)
Simple health check endpoint for testing connectivity.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Set up environment variables:
```bash
firebase functions:config:set googleai.key="YOUR_GOOGLE_AI_API_KEY"
```

## Development

Build TypeScript:
```bash
npm run build
```

Watch for changes:
```bash
npm run build:watch
```

Serve locally:
```bash
npm run serve
```

## Deployment

Deploy to Firebase:
```bash
firebase deploy --only functions
```

Or from project root:
```bash
cd functions && npm run deploy
```

## Environment Variables

The function requires the following environment variable:

- `GOOGLE_AI_API_KEY` - Google GenAI API key for Gemini access

Set via Firebase CLI:
```bash
firebase functions:config:set googleai.key="your_key_here"
```

## Security

- Function verifies user authentication
- Checks company tier (premium required)
- Validates user belongs to the requested company
- Uses 30-second timeout for AI generation
- Sanitizes and validates AI output before returning
