import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../components/settings_action_row.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);
    final company = ref.watch(companyProvider);
    final role = user?.role.toLowerCase();
    Widget heading(String title) =>
        SettingsSectionHeading(title, first: title == 'Your account');
    Widget row(IconData icon, String title, String subtitle, String path) =>
        SettingsActionRow(
            icon: icon,
            title: title,
            subtitle: subtitle,
            onTap: () => context.push(path));
    return Scaffold(
      appBar: AppBar(
          toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(22) / 22,
          title: const Text('Account & app settings')),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                children: [
                  heading('Your account'),
                  row(LucideIcons.user, 'Edit profile',
                      'Name, username and photo', '/profile/edit'),
                  row(LucideIcons.keyRound, 'Sign-in methods',
                      'Password and linked accounts', '/sign-in-methods'),
                  heading('Your business'),
                  row(
                      LucideIcons.building2,
                      'Company details',
                      company?.name ?? 'Branding and contact details',
                      '/company-branding'),
                  row(LucideIcons.briefcase, 'Services',
                      'Your service catalogue and prices', '/services'),
                  row(LucideIcons.receipt, 'Expenses',
                      'Costs and receipt attachments', '/expenses'),
                  row(LucideIcons.files, 'Templates',
                      'Documents and checklists', '/settings/templates'),
                  row(LucideIcons.bell, 'Payment reminders',
                      'Automated invoice follow-ups', '/settings/reminders'),
                  if (['owner', 'admin'].contains(role)) ...[
                    row(LucideIcons.users, 'Team management',
                        'Invitations and member roles', '/team'),
                    row(
                        LucideIcons.link,
                        'Integrations',
                        'Accounting, calendars and connected tools',
                        '/integrations'),
                  ],
                  if (role == 'owner') ...[
                    row(LucideIcons.creditCard, 'Plan & billing',
                        'Subscription and payment details', '/billing'),
                    row(LucideIcons.gift, 'Referrals',
                        'Invite another business', '/referral'),
                  ],
                  heading('Stay in touch'),
                  row(LucideIcons.messageSquare, 'Collaboration',
                      'Reviews, comments and activity', '/collaboration'),
                  row(LucideIcons.messageCircle, 'Client responses',
                      'Customer comments and approvals', '/client-responses'),
                  row(LucideIcons.bell, 'Notifications',
                      'Updates and reminders', '/notifications'),
                  heading('Appearance'),
                  SettingsActionRow(
                      icon: LucideIcons.palette,
                      title: 'Colour theme',
                      subtitle: _themeName(ref.watch(themeModeProvider)),
                      onTap: () async {
                        final mode = await showModalBottomSheet<ThemeMode>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            showDragHandle: true,
                            builder: (sheetContext) => SingleChildScrollView(
                                child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        24, 0, 24, 24),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SettingsSectionHeading(
                                              'Colour theme',
                                              first: true),
                                          RadioGroup<ThemeMode>(
                                              groupValue:
                                                  ref.read(themeModeProvider),
                                              onChanged: (value) =>
                                                  Navigator.pop(
                                                      sheetContext, value),
                                              child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    for (final mode
                                                        in ThemeMode.values)
                                                      RadioListTile<ThemeMode>(
                                                          value: mode,
                                                          title: Text(
                                                              _themeName(mode)),
                                                          contentPadding:
                                                              EdgeInsets.zero),
                                                  ])),
                                        ]))));
                        if (mode != null && context.mounted) {
                          await ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(mode);
                        }
                      }),
                ]),
          )),
    );
  }

  String _themeName(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Use device setting',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}
