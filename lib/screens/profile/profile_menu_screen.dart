import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/glass_card.dart';
import '../../components/settings_action_row.dart';
import '../../providers/providers.dart';

class ProfileMenuScreen extends ConsumerWidget {
  const ProfileMenuScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);
    final company = ref.watch(companyProvider);
    return SettingsHubContent(
      name: user?.displayName ?? 'Your account',
      email: user?.email ?? '',
      companyName: company?.name ?? '',
      photoUrl: user?.photoURL,
      tier: company?.tier ?? 'free',
      isOwner: user?.role.toLowerCase() == 'owner',
      canManageTeam: ['owner', 'admin'].contains(user?.role.toLowerCase()),
      onOpen: (path) => context.push(path),
      onSignOut: () async {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text(
                        'Your saved work will be here when you return.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Stay signed in')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Sign out'))
                    ]));
        if (confirmed != true) return;
        try {
          await ref.read(authServiceProvider).signOut();
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Could not sign out. Please try again.')));
          }
        }
      },
    );
  }
}

class SettingsHubContent extends StatelessWidget {
  const SettingsHubContent(
      {super.key,
      required this.name,
      required this.email,
      required this.companyName,
      this.photoUrl,
      required this.tier,
      required this.isOwner,
      required this.canManageTeam,
      required this.onOpen,
      required this.onSignOut});
  final String name, email, companyName, tier;
  final String? photoUrl;
  final bool isOwner, canManageTeam;
  final ValueChanged<String> onOpen;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? '?'
        : words
            .take(2)
            .map((part) => part.characters.first)
            .join()
            .toUpperCase();
    return Scaffold(
      appBar: AppBar(
          title: const Text('Settings'), automaticallyImplyLeading: false),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  const SettingsSectionHeading('Profile', first: true),
                  GlassCard(
                      onTap: () => onOpen('/profile/edit'),
                      child: Row(children: [
                        ClipOval(
                            child: SizedBox(
                                width: 56,
                                height: 56,
                                child: photoUrl != null && photoUrl!.isNotEmpty
                                    ? Image.network(photoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _avatar(context, initials))
                                    : _avatar(context, initials))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(name, style: theme.textTheme.titleLarge),
                              if (email.isNotEmpty)
                                Text(email,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant)),
                              if (companyName.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(companyName,
                                    style: theme.textTheme.bodyMedium)
                              ],
                            ])),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit_outlined,
                            semanticLabel: 'Edit profile', size: 22),
                      ])),
                  const SettingsSectionHeading('Settings'),
                  SettingsActionRow(
                      icon: LucideIcons.settings,
                      title: 'Account & app settings',
                      subtitle: 'Company, appearance and integrations',
                      onTap: () => onOpen('/settings/preferences')),
                  SettingsActionRow(
                      icon: LucideIcons.bell,
                      title: 'Notifications',
                      subtitle: 'Updates and reminders',
                      onTap: () => onOpen('/notifications')),
                  if (canManageTeam)
                    SettingsActionRow(
                        icon: LucideIcons.users,
                        title: 'Team management',
                        subtitle: 'Manage members and roles',
                        onTap: () => onOpen('/team')),
                  SettingsActionRow(
                      icon: LucideIcons.playCircle,
                      title: 'Automated workflows',
                      subtitle: 'Follow-ups and automations',
                      onTap: () => onOpen('/workflows')),
                  SettingsActionRow(
                      icon: LucideIcons.helpCircle,
                      title: 'Help & support',
                      subtitle: 'support@quoteonthego.co.uk',
                      onTap: () {
                        showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                                    title: const Text('Help & support'),
                                    content: const SelectableText(
                                        'Email support@quoteonthego.co.uk with the task you need help with.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close'))
                                    ]));
                      }),
                  if (isOwner) ...[
                    SettingsActionRow(
                        icon: LucideIcons.creditCard,
                        title: 'Plan & billing',
                        subtitle:
                            '${tier.isEmpty ? 'Free' : tier[0].toUpperCase() + tier.substring(1)} plan',
                        onTap: () => onOpen('/billing')),
                  ],
                  SettingsActionRow(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Saved requests',
                      subtitle: 'Document sync and retry status',
                      onTap: () => onOpen('/settings/saves')),
                  SettingsActionRow(
                      onTap: onSignOut, icon: Icons.logout, title: 'Sign out'),
                ]),
          )),
    );
  }

  Widget _avatar(BuildContext context, String initials) => ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
          child: Text(initials,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer))));
}
