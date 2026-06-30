import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';
import '../../components/mesh_background.dart';
import '../../components/glass_card.dart';
import '../../utils/feedback_controller.dart';
import '../../models/feedback_type.dart';

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
        ref.read(feedbackControllerProvider).error(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubscriptionLoading = false);
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isGoogleUser =
        user.providerData.any((p) => p.providerId == 'google.com');
    if (isGoogleUser) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).warning(context, 'Password change is not available for Google sign-in accounts.');
      }
      return;
    }

    if (user.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (context.mounted) {
          ref.read(feedbackControllerProvider).success(context, 'Password reset email sent to ${user.email}');
        }
      } catch (e) {
        if (context.mounted) {
          ref.read(feedbackControllerProvider).error(context, 'Error: $e');
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
            prefixIcon: Icon(LucideIcons.user),
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
          await ref.read(feedbackControllerProvider).showCelebration(
            context: context,
            type: CelebrationType.sparkle,
            title: 'Profile Updated',
            subtitle: 'Your changes have been saved',
          );
        }
      } catch (e) {
        if (context.mounted) {
          ref.read(feedbackControllerProvider).error(context, 'Error: $e');
        }
      }
    }
  }

  Color _getAvatarColor(String name, bool isDark) {
    final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> lightColors = [
      const Color(0xFFC2E7FF),
      const Color(0xFFC4EED0),
      const Color(0xFFFEEFC3),
      const Color(0xFFFAD2E1),
      const Color(0xFFE8EAED),
      const Color(0xFFD7C4F2),
    ];
    final List<Color> darkColors = [
      const Color(0xFF004A77),
      const Color(0xFF07522C),
      const Color(0xFF7A5C00),
      const Color(0xFF7D1B46),
      const Color(0xFF3C4043),
      const Color(0xFF532E7E),
    ];
    final list = isDark ? darkColors : lightColors;
    return list[hash % list.length];
  }

  Color _getAvatarTextColor(String name, bool isDark) {
    final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> lightTextColors = [
      const Color(0xFF001D35),
      const Color(0xFF072711),
      const Color(0xFF553D00),
      const Color(0xFF4B0024),
      const Color(0xFF202124),
      const Color(0xFF2C0A5E),
    ];
    final List<Color> darkTextColors = [
      const Color(0xFFC2E7FF),
      const Color(0xFFC4EED0),
      const Color(0xFFFEEFC3),
      const Color(0xFFFAD2E1),
      const Color(0xFFE8EAED),
      const Color(0xFFD7C4F2),
    ];
    final list = isDark ? darkTextColors : lightTextColors;
    return list[hash % list.length];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final userProfile = ref.watch(userProfileProvider);
    final company = ref.watch(companyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final avatarName = userProfile?.displayName ?? userProfile?.email ?? 'User';
    final avatarColor = _getAvatarColor(avatarName, isDark);
    final avatarTextColor = _getAvatarTextColor(avatarName, isDark);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: avatarColor,
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
                          color: avatarTextColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userProfile?.displayName ?? userProfile?.email ?? 'User',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (userProfile?.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      userProfile!.email!,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  if (company != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: company.tier == 'premium'
                            ? LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  Color.lerp(colorScheme.primary,
                                      Colors.orangeAccent, 0.4)!,
                                ],
                              )
                            : null,
                        color: company.tier != 'premium'
                            ? colorScheme.onSurface.withValues(alpha: 0.08)
                            : null,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: company.tier == 'premium'
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.24),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        company.tier.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: company.tier == 'premium'
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface.withValues(alpha: 0.65),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // PROFILE & COMPANY Section
            const _SectionHeader(title: 'Profile & Company'),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(LucideIcons.building2, color: colorScheme.primary),
                    title: const Text('Company Branding',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      company?.name ?? 'Tap to edit company details',
                      style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                    trailing: const Icon(LucideIcons.chevronRight, size: 14),
                    onTap: () => context.push('/company-branding'),
                  ),
                  _buildSubtleDivider(isDark),
                  ListTile(
                    leading: Icon(LucideIcons.users, color: colorScheme.primary),
                    title: const Text('Team Management',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Invite and manage team members',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    trailing: const Icon(LucideIcons.chevronRight, size: 14),
                    onTap: () => context.push('/team'),
                  ),
                  _buildSubtleDivider(isDark),
                  ListTile(
                    leading: Icon(LucideIcons.user, color: colorScheme.primary),
                    title: const Text('Sign-in Methods',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Manage passwords and linked accounts',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    trailing: const Icon(LucideIcons.chevronRight, size: 14),
                    onTap: () => context.push('/sign-in-methods'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // BUSINESS SETTINGS Section
            const _SectionHeader(title: 'Business Settings'),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(LucideIcons.hardHat, color: colorScheme.primary),
                    title: const Text('Services',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Manage your service catalogue & pricing',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    trailing: const Icon(LucideIcons.chevronRight, size: 14),
                    onTap: () => context.push('/services'),
                  ),
                  _buildSubtleDivider(isDark),
                  ListTile(
                    leading: Icon(LucideIcons.receipt, color: colorScheme.primary),
                    title: const Text('Expenses',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Track business expenses & receipts',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    trailing: const Icon(LucideIcons.chevronRight, size: 14),
                    onTap: () => context.push('/expenses'),
                  ),
                   ListTile(
                    leading: Icon(LucideIcons.layout, color: colorScheme.primary),
                    title: const Text('Templates',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Manage your document & checklist templates',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    trailing: const Icon(LucideIcons.chevronRight, size: 14),
                    onTap: () => context.push('/settings/templates'),
                  ),
                  _buildSubtleDivider(isDark),
                  ListTile(
                    leading: Icon(LucideIcons.bell, color: colorScheme.primary),
                    title: const Text('Payment Reminders',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Configure automated invoice reminders',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    trailing: const Icon(LucideIcons.chevronRight, size: 14),
                    onTap: () => context.push('/settings/reminders'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // SUBSCRIPTION & REWARDS Section (Owner only)
            if (userProfile?.role.toLowerCase() == 'owner') ...[
              const _SectionHeader(title: 'Subscription & Rewards'),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SubscriptionTile(
                      tier: company?.tier ?? 'free',
                      subscriptionStatus: company?.subscriptionStatus,
                      trialEndsAt: company?.trialEndsAt,
                      isLoading: _isSubscriptionLoading,
                      onTap: () => context.push('/billing'),
                    ),
                    _buildSubtleDivider(isDark),
                    ListTile(
                      leading: Icon(LucideIcons.gift,
                          color: const Color(0xFFF4781F)),
                      title: const Text('Referral Programme',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Earn free months by referring friends',
                          style: TextStyle(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.6))),
                      trailing: const Icon(LucideIcons.chevronRight, size: 14),
                      onTap: () => context.push('/referral'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // INTEGRATIONS Section (Owner/Admin only)
            if (userProfile?.role.toLowerCase() == 'owner' ||
                userProfile?.role.toLowerCase() == 'admin') ...[
              const _SectionHeader(title: 'Integrations'),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(LucideIcons.refreshCw, color: colorScheme.primary),
                      title: const Text('QuickBooks',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        company?.quickbooksEnabled == true
                            ? 'Connected'
                            : 'Not connected',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      trailing: Icon(
                        company?.quickbooksEnabled == true
                            ? LucideIcons.checkCircle
                            : LucideIcons.chevronRight,
                        color: company?.quickbooksEnabled == true
                            ? semanticColors.success
                            : colorScheme.onSurface.withValues(alpha: 0.3),
                        size: 20,
                      ),
                      onTap: () => context.push('/integrations'),
                    ),
                    _buildSubtleDivider(isDark),
                    ListTile(
                      leading:
                          Icon(LucideIcons.calendar, color: colorScheme.primary),
                      title: const Text('Google Calendar',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        company?.googleCalendarEnabled == true
                            ? 'Connected'
                            : 'Not connected',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      trailing: Icon(
                        company?.googleCalendarEnabled == true
                            ? LucideIcons.checkCircle
                            : LucideIcons.chevronRight,
                        color: company?.googleCalendarEnabled == true
                            ? semanticColors.success
                            : colorScheme.onSurface.withValues(alpha: 0.3),
                        size: 20,
                      ),
                      onTap: () => context.push('/integrations'),
                    ),
                    _buildSubtleDivider(isDark),
                    ListTile(
                      leading:
                          Icon(LucideIcons.table2, color: colorScheme.primary),
                      title: const Text('Monday.com',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        company?.mondayEnabled == true
                            ? 'Connected'
                            : 'Not connected',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      trailing: Icon(
                        company?.mondayEnabled == true
                            ? LucideIcons.checkCircle
                            : LucideIcons.chevronRight,
                        color: company?.mondayEnabled == true
                            ? semanticColors.success
                            : colorScheme.onSurface.withValues(alpha: 0.3),
                        size: 20,
                      ),
                      onTap: () => context.push('/integrations'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // COLLABORATION Section
            const _SectionHeader(title: 'Collaboration'),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(LucideIcons.messageSquare, color: colorScheme.primary),
                    title: const Text('Collaboration Overview',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Pending reviews, comments, activity',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    trailing: const Icon(LucideIcons.chevronRight, size: 14),
                    onTap: () => context.push('/collaboration'),
                  ),
                  _buildSubtleDivider(isDark),
                  ListTile(
                    leading: Icon(LucideIcons.messageCircle,
                        color: colorScheme.primary),
                    title: const Text('Client Responses',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Customer comments, approvals & activity',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    trailing: const Icon(LucideIcons.chevronRight, size: 14),
                    onTap: () => context.push('/client-responses'),
                  ),
                  _buildSubtleDivider(isDark),
                  ListTile(
                    leading: Icon(LucideIcons.bell,
                        color: colorScheme.primary),
                    title: const Text('Notifications',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Push notification settings',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    trailing: const Icon(LucideIcons.chevronRight, size: 14),
                    onTap: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // PREFERENCES Section
            const _SectionHeader(title: 'Preferences'),
            GlassCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(LucideIcons.moon, color: colorScheme.primary),
                title: const Text('Dark Mode',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  ref.watch(themeModeProvider) == ThemeMode.system
                      ? 'Following system setting'
                      : ref.watch(themeModeProvider) == ThemeMode.dark
                          ? 'Always dark'
                          : 'Always light',
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                trailing: Switch(
                  activeThumbColor: colorScheme.primary,
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
            ),
            const SizedBox(height: 16),

            // Danger Zone
            _SectionHeader(title: 'Danger Zone', color: semanticColors.error),
            GlassCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(LucideIcons.logOut, color: semanticColors.error),
                title: Text(
                  'Log Out',
                  style: TextStyle(
                      color: semanticColors.error, fontWeight: FontWeight.w600),
                ),
                trailing: Icon(LucideIcons.chevronRight,
                    size: 14,
                    color: semanticColors.error.withValues(alpha: 0.6)),
                onTap: () => _handleLogOut(context),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtleDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04),
    );
  }

  Future<void> _handleLogOut(BuildContext context) async {
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
        LucideIcons.creditCard,
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
                  ? LucideIcons.userCog
                  : LucideIcons.rocket,
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
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color ?? Theme.of(context).colorScheme.primary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
