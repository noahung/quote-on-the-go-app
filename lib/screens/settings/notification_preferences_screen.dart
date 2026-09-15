import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesState();
}

class _NotificationPreferencesState extends State<NotificationPreferencesScreen> {
  bool _saving = false;
  static const _events = [
    ('quotation_accepted', 'Quotation accepted', true),
    ('quotation_declined', 'Quotation declined', true),
    ('quotation_amended', 'Amendment requested', true),
    ('comment_added', 'Customer comments', false),
    ('mention', 'Mentions', false),
    ('approval_request', 'Approval requests', false),
    ('approval_update', 'Approval decisions', false),
    ('invoice_paid', 'Invoice paid', false),
    ('job_completed', 'Job completed', false),
    ('expense_added', 'Expenses', false),
    ('generic', 'Workflow updates', false),
  ];
  Future<void> _save(String path, bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.doc('users/$uid').update({'notificationPreferences.$path': value});
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save preferences. Please try again.')));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: uid == null ? const Center(child: Text('Please sign in.')) : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.doc('users/$uid').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Could not load preferences. Please reopen this screen to retry.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final preferences = snapshot.data!.data()?['notificationPreferences'] as Map<String, dynamic>? ?? {};
          final events = preferences['events'] as Map<String, dynamic>? ?? {};
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Choose alerts across all devices. Updates remain in your inbox. Customer and account security emails are managed separately.'),
            for (final channel in ['push', 'email']) SwitchListTile(
              title: Text(channel == 'push' ? 'Allow push alerts' : 'Allow team email alerts'),
              value: preferences[channel] != false,
              onChanged: _saving ? null : (value) => _save(channel, value)),
            for (final event in _events) ...[
              const Divider(),
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(event.$2, style: Theme.of(context).textTheme.titleMedium)),
              for (final channel in ['push', 'email']) SwitchListTile(
                title: Text(channel == 'push' ? 'Push' : 'Email'),
                value: (events[event.$1] as Map<String, dynamic>?)?[channel] as bool? ??
                    (channel == 'push' ? event.$1 != 'expense_added' : event.$3),
                onChanged: _saving || preferences[channel] == false ? null : (value) => _save('events.${event.$1}.$channel', value)),
            ],
          ]);
        },
      ),
    );
  }
}
