import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if user signed in with Google (no password to change)
    final isGoogleUser =
        user.providerData.any((p) => p.providerId == 'google.com');
    if (isGoogleUser) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Password change is not available for Google sign-in accounts.')),
        );
      }
      return;
    }

    if (user.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Password reset email sent to ${user.email}')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditProfileDialog(
      BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: user.displayName ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await user.updateDisplayName(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final userProfile = ref.watch(userProfileProvider);
    final company = ref.watch(companyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    userProfile?.displayName != null &&
                            userProfile!.displayName!.isNotEmpty
                        ? userProfile.displayName![0].toUpperCase()
                        : userProfile?.email != null &&
                                userProfile!.email!.isNotEmpty
                            ? userProfile.email![0].toUpperCase()
                            : '?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  userProfile?.displayName ?? userProfile?.email ?? 'User',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (userProfile?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    userProfile!.email!,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (company != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: company.tier == 'premium'
                          ? colorScheme.tertiaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      company.tier.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: company.tier == 'premium'
                            ? colorScheme.tertiary
                            : colorScheme.onSurfaceVariant,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(),

          // Company Section
          const _SectionHeader(title: 'Company'),
          ListTile(
            leading: const Icon(Icons.business),
            title: Text(company?.name ?? 'Company'),
            subtitle: Text(company?.email ?? 'No email'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Company branding is managed from the web app.')),
              );
            },
          ),

          const Divider(),

          // Account Section
          const _SectionHeader(title: 'Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showEditProfileDialog(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showChangePasswordDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Team Management'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/team'),
          ),

          const Divider(),

          // Subscription Section
          const _SectionHeader(title: 'Subscription'),
          ListTile(
            leading: const Icon(Icons.credit_card),
            title: const Text('Manage Subscription'),
            subtitle: Text(
              company?.tier == 'premium' ? 'Pro Plan — Active' : 'Free Plan',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              if (company?.tier == 'premium') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Subscription management is available on the web app.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Upgrade to Pro from the web app to unlock all features.')),
                );
              }
            },
          ),

          const Divider(),

          // Integrations Section
          const _SectionHeader(title: 'Integrations'),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('QuickBooks'),
            subtitle: Text(
              company?.quickbooksEnabled == true
                  ? 'Connected'
                  : 'Not connected',
            ),
            trailing: Icon(
              company?.quickbooksEnabled == true
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: company?.quickbooksEnabled == true
                  ? Colors.green
                  : Colors.grey,
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Integrations are managed from the web app.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Google Calendar'),
            subtitle: Text(
              company?.googleCalendarEnabled == true
                  ? 'Connected'
                  : 'Not connected',
            ),
            trailing: Icon(
              company?.googleCalendarEnabled == true
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: company?.googleCalendarEnabled == true
                  ? Colors.green
                  : Colors.grey,
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Integrations are managed from the web app.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text('Monday.com'),
            subtitle: Text(
              company?.mondayEnabled == true ? 'Connected' : 'Not connected',
            ),
            trailing: Icon(
              company?.mondayEnabled == true
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color:
                  company?.mondayEnabled == true ? Colors.green : Colors.grey,
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Integrations are managed from the web app.')),
              );
            },
          ),

          const Divider(),

          // Preferences Section
          const _SectionHeader(title: 'Preferences'),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            subtitle: const Text('Follows system setting'),
            trailing: Switch(
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Theme follows your system setting. Change it in your device settings.')),
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/notifications'),
          ),

          const Divider(),

          // Danger Zone
          const _SectionHeader(title: 'Danger Zone', color: Colors.red),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Log Out',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Log Out'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Log Out'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                final authService = ref.read(authServiceProvider);
                await authService.signOut();
              }
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionHeader({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color ?? Theme.of(context).colorScheme.primary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
