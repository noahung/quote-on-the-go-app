import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';

class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  Future<void> _launchWebApp(BuildContext context, String path) async {
    final url = Uri.parse('https://app.quoteonthego.co.uk$path');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final company = ref.watch(companyProvider);
    final userProfile = ref.watch(userProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isPremium = company?.tier == 'premium';
    final canManage = userProfile?.role == 'owner' || userProfile?.role == 'admin';

    final quickbooksConnected = company?.quickbooksEnabled == true;
    final mondayConnected = company?.mondayEnabled == true;
    final googleCalendarConnected = company?.googleCalendarEnabled == true;

    final quickbooksLastSync = company?.quickbooksLastSyncAt;
    final mondayLastSync = company?.mondayLastSyncAt;

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
            'Integrations',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header description
            Text(
              'Connect third-party services to enhance your workflow',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),

            // QuickBooks Integration
            _IntegrationCard(
              title: 'QuickBooks Online',
              description: 'Sync customers, invoices, and services with QuickBooks Online.',
              icon: Icons.account_balance_wallet_outlined,
              iconColor: const Color(0xFF2CA01C), // QuickBooks green
              isConnected: quickbooksConnected,
              isPremium: isPremium,
              lastSyncAt: quickbooksLastSync,
              canManage: canManage,
              isDark: isDark,
              colorScheme: colorScheme,
              semanticColors: semanticColors,
              onConnect: () => _launchWebApp(context, '/settings/integrations'),
              onDisconnect: () => _launchWebApp(context, '/settings/integrations'),
              onSync: () => _launchWebApp(context, '/settings/integrations'),
              actions: [
                _IntegrationAction(
                  label: 'Sync All',
                  icon: Icons.sync,
                  onTap: () => _launchWebApp(context, '/settings/integrations'),
                ),
                _IntegrationAction(
                  label: 'Import Customers',
                  icon: Icons.download,
                  onTap: () => _launchWebApp(context, '/settings/integrations'),
                ),
                _IntegrationAction(
                  label: 'Import Invoices',
                  icon: Icons.receipt_long,
                  onTap: () => _launchWebApp(context, '/settings/integrations'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Monday.com Integration
            _IntegrationCard(
              title: 'Monday.com',
              description: 'Sync quotations, invoices, and customers with Monday.com boards.',
              icon: Icons.table_chart_outlined,
              iconColor: const Color(0xFFFF3D57), // Monday red
              isConnected: mondayConnected,
              isPremium: isPremium,
              lastSyncAt: mondayLastSync,
              canManage: canManage,
              isDark: isDark,
              colorScheme: colorScheme,
              semanticColors: semanticColors,
              onConnect: () => _launchWebApp(context, '/settings/integrations'),
              onDisconnect: () => _launchWebApp(context, '/settings/integrations'),
              onSync: () => _launchWebApp(context, '/settings/integrations'),
              actions: [
                _IntegrationAction(
                  label: 'Board Config',
                  icon: Icons.settings,
                  onTap: () => _launchWebApp(context, '/settings/integrations'),
                ),
                _IntegrationAction(
                  label: 'Sync Now',
                  icon: Icons.sync,
                  onTap: () => _launchWebApp(context, '/settings/integrations'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Google Calendar Integration
            _IntegrationCard(
              title: 'Google Calendar',
              description: 'Sync your scheduled jobs with Google Calendar.',
              icon: Icons.calendar_today_outlined,
              iconColor: const Color(0xFF4285F4), // Google blue
              isConnected: googleCalendarConnected,
              isPremium: isPremium,
              canManage: canManage,
              isDark: isDark,
              colorScheme: colorScheme,
              semanticColors: semanticColors,
              onConnect: () => _launchWebApp(context, '/settings'),
              onDisconnect: () => _launchWebApp(context, '/settings'),
              onSync: () => _launchWebApp(context, '/settings'),
              showLastSync: false,
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
                      'Full integration setup and configuration are available on the web app for the best experience.',
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
}

class _IntegrationAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _IntegrationAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _IntegrationCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final bool isConnected;
  final bool isPremium;
  final DateTime? lastSyncAt;
  final bool canManage;
  final bool isDark;
  final ColorScheme colorScheme;
  final SemanticColors semanticColors;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onSync;
  final List<_IntegrationAction>? actions;
  final bool showLastSync;

  const _IntegrationCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.isConnected,
    required this.isPremium,
    required this.canManage,
    required this.isDark,
    required this.colorScheme,
    required this.semanticColors,
    required this.onConnect,
    required this.onDisconnect,
    required this.onSync,
    this.lastSyncAt,
    this.actions,
    this.showLastSync = true,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
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
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!isPremium) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            isConnected ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 14,
                            color: isConnected ? semanticColors.success : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isConnected ? 'Connected' : 'Not connected',
                            style: TextStyle(
                              fontSize: 13,
                              color: isConnected
                                  ? semanticColors.success
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ),

          // Last sync info
          if (showLastSync && isConnected && lastSyncAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
              child: Text(
                'Last synced: ${_formatDate(lastSyncAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Action buttons
          if (isConnected && actions != null && actions!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions!.map((action) {
                  return OutlinedButton.icon(
                    onPressed: canManage ? action.onTap : null,
                    icon: Icon(action.icon, size: 16),
                    label: Text(action.label),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ),

          if (isConnected && actions != null && actions!.isNotEmpty)
            const SizedBox(height: 16),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),

          // Main action
          InkWell(
            onTap: canManage
                ? (isConnected ? onDisconnect : onConnect)
                : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isConnected ? Icons.link_off : Icons.link,
                    size: 18,
                    color: isConnected
                        ? semanticColors.error
                        : colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected ? 'Disconnect' : 'Connect',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isConnected
                          ? semanticColors.error
                          : colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
