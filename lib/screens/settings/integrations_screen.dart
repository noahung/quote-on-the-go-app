import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';

class IntegrationsScreen extends ConsumerStatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  ConsumerState<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends ConsumerState<IntegrationsScreen> {
  bool _qbLoading = false;
  bool _mondayLoading = false;
  bool _gcalLoading = false;

  Future<void> _launchUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open browser')),
        );
      }
    }
  }

  Future<void> _connectQuickBooks(BuildContext context) async {
    final company = ref.read(companyProvider);
    if (company == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _qbLoading = true);
    try {
      final service = ref.read(integrationServiceProvider);
      final authUrl = await service.connectQuickBooks(companyId: company.id);
      if (!mounted) return;
      await _launchUrl(this.context, authUrl);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to connect QuickBooks: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _qbLoading = false);
    }
  }

  Future<void> _disconnectQuickBooks(BuildContext context) async {
    final company = ref.read(companyProvider);
    if (company == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect QuickBooks?'),
        content: const Text('This will revoke access. Your data will not be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _qbLoading = true);
    try {
      final service = ref.read(integrationServiceProvider);
      await service.disconnectQuickBooks(companyId: company.id);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('QuickBooks disconnected'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _qbLoading = false);
    }
  }

  Future<void> _connectMonday(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _mondayLoading = true);
    try {
      final service = ref.read(integrationServiceProvider);
      final authUrl = await service.connectMonday();
      if (!mounted) return;
      await _launchUrl(this.context, authUrl);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to connect Monday.com: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _mondayLoading = false);
    }
  }

  Future<void> _disconnectMonday(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Monday.com?'),
        content: const Text('This will remove board mappings. Your data will not be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _mondayLoading = true);
    try {
      final service = ref.read(integrationServiceProvider);
      await service.disconnectMonday();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Monday.com disconnected'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _mondayLoading = false);
    }
  }

  Future<void> _showMondayBoardConfig(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    List<Map<String, dynamic>> boards = [];
    bool isLoadingBoards = true;
    String? quotationsBoardId;
    String? invoicesBoardId;
    String? customersBoardId;

    final company = ref.read(companyProvider);
    quotationsBoardId = company?.mondayQuotationsBoardId;
    invoicesBoardId = company?.mondayInvoicesBoardId;
    customersBoardId = company?.mondayCustomersBoardId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (isLoadingBoards) {
            isLoadingBoards = false;
            ref.read(integrationServiceProvider).getMondayBoards().then((result) {
              setSheetState(() => boards = result);
            }).catchError((e) {
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to load boards: $e'), backgroundColor: Colors.red),
                );
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configure Monday.com Boards',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                if (boards.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _BoardDropdown(
                    label: 'Quotations Board',
                    boards: boards,
                    value: quotationsBoardId,
                    onChanged: (v) => setSheetState(() => quotationsBoardId = v),
                  ),
                  const SizedBox(height: 12),
                  _BoardDropdown(
                    label: 'Invoices Board',
                    boards: boards,
                    value: invoicesBoardId,
                    onChanged: (v) => setSheetState(() => invoicesBoardId = v),
                  ),
                  const SizedBox(height: 12),
                  _BoardDropdown(
                    label: 'Customers Board',
                    boards: boards,
                    value: customersBoardId,
                    onChanged: (v) => setSheetState(() => customersBoardId = v),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        try {
                          await ref.read(integrationServiceProvider).configureMondayBoards(
                                quotationsBoardId: quotationsBoardId,
                                invoicesBoardId: invoicesBoardId,
                                customersBoardId: customersBoardId,
                              );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text('Board configuration saved'),
                                  backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text('Failed to save: $e'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: const Text('Save Configuration'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _connectGoogleCalendar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(integrationServiceProvider);
    final url = service.getGoogleCalendarConnectUrl();
    await _launchUrl(context, url);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Complete the OAuth flow in your browser. The integration will appear here once connected.'),
      ),
    );
  }

  Future<void> _disconnectGoogleCalendar(BuildContext context) async {
    final company = ref.read(companyProvider);
    if (company == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Google Calendar?'),
        content: const Text('Scheduled jobs will no longer sync to your calendar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _gcalLoading = true);
    try {
      final service = ref.read(integrationServiceProvider);
      await service.disconnectGoogleCalendar(companyId: company.id);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Google Calendar disconnected'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _gcalLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final company = ref.watch(companyProvider);
    final userProfile = ref.watch(userProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tier = company?.tier;
    final isPremium = tier == 'premium' || tier == 'individual' || tier == 'organisation';
    final role = userProfile?.role.toLowerCase();
    final canManage = role == 'owner' || role == 'admin';

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
            Text(
              'Connect third-party services to enhance your workflow',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),

            _IntegrationCard(
              title: 'QuickBooks Online',
              description: 'Sync customers, invoices, and services with QuickBooks Online.',
              icon: LucideIcons.wallet,
              iconColor: const Color(0xFF2CA01C),
              isConnected: quickbooksConnected,
              isPremium: isPremium,
              lastSyncAt: quickbooksLastSync,
              canManage: canManage,
              isDark: isDark,
              colorScheme: colorScheme,
              semanticColors: semanticColors,
              isLoading: _qbLoading,
              onConnect: () => _connectQuickBooks(context),
              onDisconnect: () => _disconnectQuickBooks(context),
              actions: [
                _IntegrationAction(
                  label: 'Sync All',
                  icon: LucideIcons.refreshCw,
                  onTap: () => _launchUrl(context, 'https://app.quoteonthego.co.uk/settings/integrations'),
                ),
                _IntegrationAction(
                  label: 'Import Customers',
                  icon: LucideIcons.download,
                  onTap: () => _launchUrl(context, 'https://app.quoteonthego.co.uk/settings/integrations'),
                ),
                _IntegrationAction(
                  label: 'Import Invoices',
                  icon: LucideIcons.receipt,
                  onTap: () => _launchUrl(context, 'https://app.quoteonthego.co.uk/settings/integrations'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _IntegrationCard(
              title: 'Monday.com',
              description: 'Sync quotations, invoices, and customers with Monday.com boards.',
              icon: LucideIcons.table2,
              iconColor: const Color(0xFFFF3D57),
              isConnected: mondayConnected,
              isPremium: isPremium,
              lastSyncAt: mondayLastSync,
              canManage: canManage,
              isDark: isDark,
              colorScheme: colorScheme,
              semanticColors: semanticColors,
              isLoading: _mondayLoading,
              onConnect: () => _connectMonday(context),
              onDisconnect: () => _disconnectMonday(context),
              actions: [
                _IntegrationAction(
                  label: 'Board Config',
                  icon: LucideIcons.settings,
                  onTap: () => _showMondayBoardConfig(context),
                ),
                _IntegrationAction(
                  label: 'Sync Now',
                  icon: LucideIcons.refreshCw,
                  onTap: () => _launchUrl(context, 'https://app.quoteonthego.co.uk/settings/integrations'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _IntegrationCard(
              title: 'Google Calendar',
              description: 'Sync your scheduled jobs with Google Calendar.',
              icon: LucideIcons.calendar,
              iconColor: const Color(0xFF4285F4),
              isConnected: googleCalendarConnected,
              isPremium: isPremium,
              canManage: canManage,
              isDark: isDark,
              colorScheme: colorScheme,
              semanticColors: semanticColors,
              isLoading: _gcalLoading,
              onConnect: () => _connectGoogleCalendar(context),
              onDisconnect: () => _disconnectGoogleCalendar(context),
              showLastSync: false,
            ),

            const SizedBox(height: 24),

            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'OAuth callbacks complete in your browser. The connection status updates automatically here once linked.',
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

class _BoardDropdown extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> boards;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _BoardDropdown({
    required this.label,
    required this.boards,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      initialValue: value,
      items: [
        const DropdownMenuItem(value: null, child: Text('Not configured')),
        ...boards.map((b) => DropdownMenuItem(
              value: b['id'] as String?,
              child: Text(b['name'] as String? ?? 'Unknown'),
            )),
      ],
      onChanged: onChanged,
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
  final List<_IntegrationAction>? actions;
  final bool showLastSync;
  final bool isLoading;

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
    this.lastSyncAt,
    this.actions,
    this.showLastSync = true,
    this.isLoading = false,
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
                            isConnected ? LucideIcons.checkCircle : LucideIcons.circle,
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
            onTap: canManage && !isLoading
                ? (isConnected ? onDisconnect : onConnect)
                : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isConnected ? semanticColors.error : colorScheme.primary,
                      ),
                    )
                  else ...[
                    Icon(
                      isConnected ? LucideIcons.unlink : LucideIcons.link,
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
