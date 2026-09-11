const List<Map<String, dynamic>> builtInWorkflowTemplates = [
    {
      'title': 'High-Value Client Sequence',
      'desc': 'Special high-touch delay triggers and customized premium emails designed for corporate jobs.',
      'trigger': 'QUOTE SENT > £5,000',
      'type': 'quotation_sent',
      'conditions': [{'field': 'amount', 'operator': 'greater_than', 'value': '5000'}],
      'steps': [
        {'order': 0, 'type': 'send_email', 'subject': 'Your Quotation is Ready', 'body': 'Dear customer, your tailored quotation is ready to view using the link below.'},
        {'order': 1, 'type': 'wait', 'waitDays': 3},
        {'order': 2, 'type': 'send_email', 'subject': 'Following Up on Your Quotation', 'body': 'Just checking in — we would love to help with your project.'},
        {'order': 3, 'type': 'wait', 'waitDays': 5},
        {'order': 4, 'type': 'send_email', 'subject': 'Your quotation is still valid', 'body': 'Final reminder: your quote is still valid. Reply to confirm.'},
      ],
    },
    {
      'title': 'Invoice Overdue Automated Alert',
      'desc': 'Sends four email reminders over 14 days when invoices pass the due date.',
      'trigger': 'INVOICE OVERDUE 1 DAY',
      'type': 'invoice_overdue',
      'steps': [
        {'order': 0, 'type': 'send_email', 'subject': 'Invoice Overdue Reminder', 'body': 'Your invoice is now overdue. Please arrange payment at your earliest convenience.'},
        {'order': 1, 'type': 'wait', 'waitDays': 3},
        {'order': 2, 'type': 'send_email', 'subject': 'Second Overdue Notice', 'body': 'This is a second reminder that your invoice remains unpaid.'},
        {'order': 3, 'type': 'wait', 'waitDays': 7},
        {'order': 4, 'type': 'send_email', 'subject': 'Invoice overdue', 'body': 'Your invoice is overdue. Please contact us to arrange payment.'},
        {'order': 5, 'type': 'wait', 'waitDays': 4},
        {'order': 6, 'type': 'send_email', 'subject': 'Final Overdue Notice', 'body': 'We have not received payment. This is our final notice before further action.'},
      ],
    },
    {
      'title': 'Quick Feedback Collection',
      'desc': 'Sends a polite satisfaction survey link 2 days after payment confirmation.',
      'trigger': 'INVOICE PAID',
      'type': 'invoice_paid',
      'steps': [
        {'order': 0, 'type': 'wait', 'waitDays': 2},
        {'order': 1, 'type': 'send_email', 'subject': 'How Did We Do?', 'body': 'Thank you for your payment! We would love your feedback — it only takes 1 minute.'},
      ],
    },
  ];

