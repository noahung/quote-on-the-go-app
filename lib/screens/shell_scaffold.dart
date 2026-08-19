import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../components/mesh_background.dart';
import '../theme/semantic_colors.dart';
import '../models/company.dart';

class ShellScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const ShellScaffold({super.key, required this.child});

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> {
  int _currentIndex = 0;

  void _showQuickActionsBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              padding: const EdgeInsets.only(top: 12, bottom: 32, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pull handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create New',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'What would you like to create?',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action Cards - Now only 2 options
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          context,
                          title: 'Create Quote',
                          desc: 'Draft new offer',
                          icon: LucideIcons.fileText,
                          color: const Color(0xFFF4781F),
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/quotations/new');
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          title: 'Create Invoice',
                          desc: 'Log new billing',
                          icon: LucideIcons.receipt,
                          color: Colors.green,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/invoices/new');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: SizedBox(
          height: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final company = ref.watch(companyProvider);
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isEffectivelyFreeTier = company?.tier == 'free' || company?.tier == null;

    // Update current index based on location
    // Bottom Nav: 0=Dashboard, 1=Schedule, 2=Customers, 3=Settings
    if (location == '/') {
      _currentIndex = 0;
    } else if (location.startsWith('/schedule')) {
      _currentIndex = 1;
    } else if (location.startsWith('/customers')) {
      _currentIndex = 2;
    } else if (location.startsWith('/settings')) {
      _currentIndex = 3;
    } else {
      _currentIndex = -1; // No tab selected for subroutes/other routes
    }

    final drawerKey = ref.watch(drawerControllerProvider);

    return MeshBackground(
      child: Scaffold(
        key: drawerKey,
        backgroundColor: Colors.transparent, // Transparent to show global MeshBackground
        drawer: _buildNavigationDrawer(context, company),
        body: widget.child,
        floatingActionButton: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF4781F).withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: FloatingActionButton(
            backgroundColor: const Color(0xFFF4781F),
            shape: const CircleBorder(),
            elevation: 0,
            onPressed: () => _showQuickActionsBottomSheet(context),
            child: const Icon(LucideIcons.plus, color: Colors.white, size: 28),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEffectivelyFreeTier)
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.star,
                              size: 18,
                              color: semanticColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Free Plan - Upgrade for unlimited access',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/settings'),
                              style: TextButton.styleFrom(
                                foregroundColor: semanticColors.warning,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: const StadiumBorder(),
                                backgroundColor: semanticColors.warning.withValues(alpha: 0.12),
                              ),
                              child: const Text(
                                'Upgrade',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 64,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTabItem(
                            context,
                            index: 0,
                            icon: LucideIcons.layoutDashboard,
                            activeIcon: LucideIcons.layoutDashboard,
                            label: 'Dashboard',
                          ),
                          _buildTabItem(
                            context,
                            index: 1,
                            icon: LucideIcons.calendar,
                            activeIcon: LucideIcons.calendar,
                            label: 'Schedule',
                          ),
                          const SizedBox(width: 48), // Center spacing for FAB
                          _buildTabItem(
                            context,
                            index: 2,
                            icon: LucideIcons.users,
                            activeIcon: LucideIcons.users,
                            label: 'Customers',
                          ),
                          _buildTabItem(
                            context,
                            index: 3,
                            icon: LucideIcons.settings,
                            activeIcon: LucideIcons.settings,
                            label: 'Settings',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = const Color(0xFFF4781F);
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;

    return Expanded(
      child: InkWell(
        onTap: () {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/schedule');
              break;
            case 2:
              context.go('/customers');
              break;
            case 3:
              context.go('/settings');
              break;
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
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
