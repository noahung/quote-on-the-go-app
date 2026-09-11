import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../models/company.dart';
import '../providers/document_outbox_provider.dart';

class ShellScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const ShellScaffold({super.key, required this.child});

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> {
  int _currentIndex = 0;

  void _showQuickActionsBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                      leading: const Icon(LucideIcons.fileText),
                      title: const Text('Create quote'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        context.push('/quotations/new');
                      }),
                  ListTile(
                      leading: const Icon(LucideIcons.receipt),
                      title: const Text('Create invoice'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        context.push('/invoices/new');
                      }),
                ]))));
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final company = ref.watch(companyProvider);
    final queue = ref.watch(documentOutboxProvider);
    _currentIndex = location.startsWith('/schedule')
        ? 1
        : location.startsWith('/customers')
            ? 2
            : location.startsWith('/settings')
                ? 3
                : 0;
    return Scaffold(
      key: ref.watch(drawerControllerProvider),
      drawer: _buildNavigationDrawer(context, company),
      body: widget.child,
      floatingActionButton: location == '/' ||
              location.startsWith('/settings') ||
              location == '/analytics'
          ? null
          : FloatingActionButton(
              tooltip: 'Create document',
              onPressed: () => _showQuickActionsBottomSheet(context),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
              child: const Icon(LucideIcons.plus)),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if ((queue?.pendingCount ?? 0) > 0 || queue?.storageError != null)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextButton.icon(
                  onPressed: () => context.push('/settings/saves'),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(queue?.storageError != null
                      ? 'Review saved requests'
                      : '${queue!.pendingCount} saved requests waiting to sync'))),
        NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => context
                .go(const ['/', '/schedule', '/customers', '/settings'][index]),
            destinations: const [
              NavigationDestination(
                  icon: Icon(LucideIcons.house), label: 'Home'),
              NavigationDestination(
                  icon: Icon(LucideIcons.calendar), label: 'Schedule'),
              NavigationDestination(
                  icon: Icon(LucideIcons.users), label: 'Customers'),
              NavigationDestination(
                  icon: Icon(LucideIcons.settings), label: 'Settings'),
            ]),
      ]),
    );
  }

  Widget _buildNavigationDrawer(BuildContext context, Company? company) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProfile = ref.watch(userProfileProvider);

    final initials = () {
      final name = userProfile?.displayName ?? userProfile?.email ?? '';
      if (name.isEmpty) return '?';
      final parts = name.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }();

    return NavigationDrawer(
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      children: [
        // Header with user info
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userProfile?.displayName ?? 'User',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (company?.name != null)
                          Text(
                            company!.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(
                color: isDark ? Colors.white12 : Colors.black12,
                height: 1,
              ),
            ],
          ),
        ),

        // Menu Items
        _buildDrawerItem(
          context,
          icon: LucideIcons.fileText,
          label: 'Quotations',
          onTap: () {
            Navigator.pop(context);
            context.go('/quotations');
          },
        ),
        _buildDrawerItem(
          context,
          icon: LucideIcons.receipt,
          label: 'Invoices',
          onTap: () {
            Navigator.pop(context);
            context.go('/invoices');
          },
        ),
        _buildDrawerItem(
          context,
          icon: LucideIcons.kanban,
          label: 'Pipeline',
          onTap: () {
            Navigator.pop(context);
            context.push('/pipeline');
          },
        ),
        _buildDrawerItem(
          context,
          icon: LucideIcons.refreshCw,
          label: 'Workflows',
          onTap: () {
            Navigator.pop(context);
            context.go('/workflows');
          },
        ),
        _buildDrawerItem(
          context,
          icon: LucideIcons.hardHat,
          label: 'Services',
          onTap: () {
            Navigator.pop(context);
            context.push('/services');
          },
        ),
        _buildDrawerItem(
          context,
          icon: LucideIcons.coins,
          label: 'Smart Pricing',
          onTap: () {
            Navigator.pop(context);
            context.push('/pricing');
          },
        ),
        _buildDrawerItem(
          context,
          icon: LucideIcons.trendingUp,
          label: 'Analytics',
          onTap: () {
            Navigator.pop(context);
            context.go('/analytics');
          },
        ),
        _buildDrawerItem(
          context,
          icon: LucideIcons.dollarSign,
          label: 'Expenses',
          onTap: () {
            Navigator.pop(context);
            context.push('/expenses');
          },
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Divider(),
        ),

        _buildDrawerItem(
          context,
          icon: LucideIcons.settings,
          label: 'Settings',
          onTap: () {
            Navigator.pop(context);
            context.push('/settings');
          },
        ),
        _buildDrawerItem(
          context,
          icon: LucideIcons.helpCircle,
          label: 'Help & Support',
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('For support, email support@quoteonthego.co.uk'),
                duration: Duration(seconds: 4),
              ),
            );
          },
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final location = GoRouterState.of(context).matchedLocation;
    final isActive = _isDrawerItemActive(location, label);

    return ListTile(
      leading: Icon(
        icon,
        color: isActive
            ? const Color(0xFFF4781F)
            : (isDark ? Colors.white70 : Colors.black54),
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: isActive
              ? const Color(0xFFF4781F)
              : (isDark ? Colors.white : Colors.black87),
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selected: isActive,
      selectedColor: const Color(0xFFF4781F),
      selectedTileColor: isDark
          ? const Color(0xFFF4781F).withValues(alpha: 0.1)
          : const Color(0xFFF4781F).withValues(alpha: 0.08),
      onTap: onTap,
    );
  }

  bool _isDrawerItemActive(String location, String label) {
    switch (label) {
      case 'Quotations':
        return location.startsWith('/quotations') && !location.contains('/new');
      case 'Invoices':
        return location.startsWith('/invoices') && !location.contains('/new');
      case 'Pipeline':
        return location.startsWith('/pipeline');
      case 'Workflows':
        return location.startsWith('/workflows');
      case 'Services':
        return location.startsWith('/services') && !location.contains('/new');
      case 'Smart Pricing':
        return location.startsWith('/pricing');
      case 'Analytics':
        return location.startsWith('/analytics');
      case 'Expenses':
        return location.startsWith('/expenses');
      case 'Settings':
        return location.startsWith('/settings');
      default:
        return false;
    }
  }
}
