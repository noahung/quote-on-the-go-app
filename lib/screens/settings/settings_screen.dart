import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../providers/providers.dart';

const String _webAppBaseUrl = 'https://app.quoteonthego.co.uk';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSubscriptionLoading = false;

  Future<void> _manageSubscription(BuildContext context) async {
    final company = ref.read(companyProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (company == null || user == null) return;

    setState(() => _isSubscriptionLoading = true);

    try {
      final bool isPremium = company.tier == 'premium' &&
          (company.subscriptionStatus == 'active' ||
              company.subscriptionStatus == 'referral_trial');

      String? redirectUrl;

      if (isPremium) {
        // Open Stripe Customer Portal
        if (company.stripeCustomerId == null) {
          throw Exception(
              'Stripe customer ID not found. Please contact support.');
        }
        final response = await http.post(
          Uri.parse(
              '$_webAppBaseUrl/api/stripe/create-customer-portal-session'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'stripeCustomerId': company.stripeCustomerId}),
        );
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode != 200) {
          throw Exception(data['error'] ?? 'Failed to open customer portal.');
        }
        redirectUrl = data['url'] as String?;
      } else {
        // Open Stripe Checkout (upgrade)
        final response = await http.post(
          Uri.parse('$_webAppBaseUrl/api/stripe/create-checkout-session'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'companyId': company.id,
            'userEmail': user.email,
          }),
        );
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode != 200) {
          throw Exception(
              data['error'] ?? 'Failed to create checkout session.');
        }
        redirectUrl = data['url'] as String?;
      }

      if (redirectUrl != null) {
        final uri = Uri.parse(redirectUrl);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw Exception('Could not open browser.');
        }
      } else {
        throw Exception('No redirect URL returned from server.');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubscriptionLoading = false);
    }
  }

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
  Widget build(BuildContext context) {
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
            subtitle: Text(company?.email ?? 'Tap to edit branding'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/company-branding'),
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
          _SubscriptionTile(
            tier: company?.tier ?? 'free',
            subscriptionStatus: company?.subscriptionStatus,
            trialEndsAt: company?.trialEndsAt,
            isLoading: _isSubscriptionLoading,
            onTap: () => _manageSubscription(context),
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
            subtitle: Text(
              ref.watch(themeModeProvider) == ThemeMode.system
                  ? 'Following system setting'
                  : ref.watch(themeModeProvider) == ThemeMode.dark
                      ? 'Always dark'
                      : 'Always light',
            ),
            trailing: Switch(
              value: ref.watch(themeModeProvider) == ThemeMode.dark ||
                  (ref.watch(themeModeProvider) == ThemeMode.system &&
                      Theme.of(context).brightness == Brightness.dark),
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
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
              // ignore: use_build_context_synchronously
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final String tier;
  final String? subscriptionStatus;
  final DateTime? trialEndsAt;
  final bool isLoading;
  final VoidCallback onTap;

  const _SubscriptionTile({
    required this.tier,
    required this.isLoading,
    required this.onTap,
    this.subscriptionStatus,
    this.trialEndsAt,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPremium = tier == 'premium';
    final isActive = isPremium &&
        (subscriptionStatus == 'active' ||
            subscriptionStatus == 'referral_trial');
    final isReferralTrial = subscriptionStatus == 'referral_trial';

    String subtitle;
    if (isReferralTrial && trialEndsAt != null) {
      final end =
          '${trialEndsAt!.day}/${trialEndsAt!.month}/${trialEndsAt!.year}';
      subtitle = 'Pro Trial — ends $end';
    } else if (isActive) {
      subtitle = 'Pro Plan — Active';
    } else if (isPremium) {
      subtitle = 'Pro Plan (${subscriptionStatus ?? 'inactive'})';
    } else {
      subtitle = 'Free Plan — Tap to upgrade to Pro (£29/mo)';
    }

    return ListTile(
      leading: Icon(
        Icons.credit_card,
        color: isActive ? colorScheme.primary : null,
      ),
      title: Text(
        isActive ? 'Manage Subscription' : 'Upgrade to Pro',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isActive ? null : colorScheme.primary,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isActive
                  ? Icons.manage_accounts_outlined
                  : Icons.rocket_launch_outlined,
              color: isActive ? null : colorScheme.primary,
              size: 20,
            ),
      onTap: isLoading ? null : onTap,
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
