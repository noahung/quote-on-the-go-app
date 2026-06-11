import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../theme/semantic_colors.dart';
import '../../utils/feedback_controller.dart';

final authProvidersProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return FirebaseAuth.instance.authStateChanges().map((user) {
    if (user == null) return [];
    return user.providerData.map((p) => p.providerId).toList();
  });
});

class SignInMethodsScreen extends ConsumerWidget {
  const SignInMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final providersAsync = ref.watch(authProvidersProvider);

    final hasPassword = providersAsync.valueOrNull?.contains('password') ?? false;
    final hasGoogle = providersAsync.valueOrNull?.contains('google.com') ?? false;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/settings');
              }
            },
          ),
          title: const Text(
            'Sign-in Methods',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Description
            Text(
              'Manage the ways you log into your account. Keep at least one method active at all times.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),

            // Security warning if only one provider
            if (user != null && (user.providerData.length <= 1))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Secure your account: You must keep at least one sign-in method active. Link another method before disabling your current one.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Email/Password Provider
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ProviderRow(
                    icon: Icons.email_outlined,
                    iconColor: colorScheme.primary,
                    title: 'Email & Password',
                    subtitle: user?.email ?? 'Not configured',
                    isConnected: hasPassword,
                    onConnect: () => _showSetPasswordDialog(context),
                    onDisconnect: user != null && user.providerData.length > 1
                        ? () => _unlinkProvider(context, 'password')
                        : null,
                    onAction: hasPassword
                        ? () => _showChangePasswordDialog(context)
                        : null,
                    actionLabel: hasPassword ? 'Change Password' : 'Set Password',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Google Provider
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ProviderRow(
                    icon: Icons.g_mobiledata,
                    iconColor: const Color(0xFF4285F4),
                    title: 'Google Login',
                    subtitle: hasGoogle
                        ? (user?.email ?? 'Connected')
                        : 'Not connected',
                    isConnected: hasGoogle,
                    onConnect: () => _linkGoogle(context),
                    onDisconnect: user != null && user.providerData.length > 1
                        ? () => _unlinkProvider(context, 'google.com')
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Info card
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'For security reasons, you cannot disable your only sign-in method. Add a backup method first.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSetPasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Set Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Set a password for your account. You\'ll be able to log in with your email and this password.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Min 6 characters',
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                  validator: (v) {
                    if (v != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setState(() => isLoading = true);

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        final email = user?.email;

                        if (user == null || email == null) {
                          throw Exception('User not logged in');
                        }

                        final credential = EmailAuthProvider.credential(
                          email: email,
                          password: passwordController.text,
                        );

                        await user.linkWithCredential(credential);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ProviderContainer container = ProviderScope.containerOf(context);
                          container.read(feedbackControllerProvider).success(context, 'Password set successfully');
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (ctx.mounted) {
                          ProviderContainer container = ProviderScope.containerOf(context);
                          container.read(feedbackControllerProvider).error(context, 'Error: $e');
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Set Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Current password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Min 6 characters',
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                  ),
                  validator: (v) {
                    if (v != newController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setState(() => isLoading = true);

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        final email = user?.email;

                        if (user == null || email == null) {
                          throw Exception('User not logged in');
                        }

                        // Re-authenticate with current password
                        final credential = EmailAuthProvider.credential(
                          email: email,
                          password: currentController.text,
                        );
                        await user.reauthenticateWithCredential(credential);

                        // Update password
                        await user.updatePassword(newController.text);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          final container = ProviderScope.containerOf(context);
                          container.read(feedbackControllerProvider).success(context, 'Password changed successfully');
                        }
                      } on FirebaseAuthException catch (e) {
                        setState(() => isLoading = false);
                        if (ctx.mounted) {
                          String message = 'Failed to change password';
                          if (e.code == 'wrong-password') {
                            message = 'Current password is incorrect';
                          }
                          final container = ProviderScope.containerOf(context);
                          container.read(feedbackControllerProvider).error(context, message);
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (ctx.mounted) {
                          final container = ProviderScope.containerOf(context);
                          container.read(feedbackControllerProvider).error(context, 'Error: $e');
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlinkProvider(BuildContext context, String providerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Sign-in Method?'),
        content: Text(
          'Are you sure you want to remove ${providerId == 'password' ? 'email/password login' : 'Google login'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await user.unlink(providerId);

      if (context.mounted) {
        final container = ProviderScope.containerOf(context);
        container.read(feedbackControllerProvider).success(context, 'Sign-in method removed');
      }
    } catch (e) {
      if (context.mounted) {
        final container = ProviderScope.containerOf(context);
        container.read(feedbackControllerProvider).error(context, 'Error: $e');
      }
    }
  }

  Future<void> _linkGoogle(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Show info that this needs to be done on web for now
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Link Google Account'),
          content: const Text(
            'To link your Google account, please use the web app at app.quoteonthego.co.uk/settings',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        final container = ProviderScope.containerOf(context);
        container.read(feedbackControllerProvider).error(context, 'Error: $e');
      }
    }
  }
}

class _ProviderRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isConnected;
  final VoidCallback onConnect;
  final VoidCallback? onDisconnect;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _ProviderRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isConnected,
    required this.onConnect,
    this.onDisconnect,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (isConnected) ...[
            if (onAction != null)
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: Text(actionLabel!),
              ),
            if (onAction != null)
              const SizedBox(width: 8),
            if (onDisconnect != null)
              IconButton(
                icon: Icon(Icons.link_off, color: semanticColors.error, size: 20),
                onPressed: onDisconnect,
                tooltip: 'Disconnect',
              ),
          ] else
            FilledButton(
              onPressed: onConnect,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }
}
