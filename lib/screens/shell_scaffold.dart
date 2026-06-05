import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../components/mesh_background.dart';
import '../theme/semantic_colors.dart';

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
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
            padding: const EdgeInsets.only(top: 12, bottom: 24, left: 24, right: 24),
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
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                // Action Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                  children: [
                    _buildActionCard(
                      context,
                      title: 'Create Quote',
                      desc: 'Draft new offer',
                      icon: Icons.description_outlined,
                      color: const Color(0xFFF4781F),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/quotations/new');
                      },
                    ),
                    _buildActionCard(
                      context,
                      title: 'Create Invoice',
                      desc: 'Log new billing',
                      icon: Icons.receipt_outlined,
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/invoices/new');
                      },
                    ),
                    _buildActionCard(
                      context,
                      title: 'Workflows',
                      desc: 'Automations',
                      icon: Icons.auto_mode,
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/workflows');
                      },
                    ),
                    _buildActionCard(
                      context,
                      title: 'Smart Pricing',
                      desc: 'Optimize margins',
                      icon: Icons.psychology,
                      color: Colors.teal,
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/pricing');
                      },
                    ),
                    _buildActionCard(
                      context,
                      title: 'Analytics',
                      desc: 'Advanced insights',
                      icon: Icons.insights,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/analytics');
                      },
                    ),
                    _buildActionCard(
                      context,
                      title: 'Schedule',
                      desc: 'Job calendar',
                      icon: Icons.calendar_today_outlined,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/schedule');
                      },
                    ),
                  ],
                ),
              ],
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final company = ref.watch(companyProvider);
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isEffectivelyFreeTier = company?.tier == 'free' || company?.tier == null;

    // Update current index based on location
    if (location == '/') {
      _currentIndex = 0;
    } else if (location.startsWith('/quotations')) {
      _currentIndex = 1;
    } else if (location.startsWith('/invoices')) {
      _currentIndex = 2;
    } else if (location.startsWith('/customers')) {
      _currentIndex = 3;
    } else {
      _currentIndex = -1; // No tab selected for subroutes/other routes
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent, // Transparent to show global MeshBackground
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
            child: const Icon(Icons.add, color: Colors.white, size: 28),
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
                              Icons.workspace_premium,
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
                            icon: Icons.dashboard_outlined,
                            activeIcon: Icons.dashboard,
                            label: 'Dashboard',
                          ),
                          _buildTabItem(
                            context,
                            index: 1,
                            icon: Icons.description_outlined,
                            activeIcon: Icons.description,
                            label: 'Quotations',
                          ),
                          const SizedBox(width: 48), // Center spacing for FAB
                          _buildTabItem(
                            context,
                            index: 2,
                            icon: Icons.receipt_outlined,
                            activeIcon: Icons.receipt,
                            label: 'Invoices',
                          ),
                          _buildTabItem(
                            context,
                            index: 3,
                            icon: Icons.people_outlined,
                            activeIcon: Icons.people,
                            label: 'Customers',
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
              context.go('/quotations');
              break;
            case 2:
              context.go('/invoices');
              break;
            case 3:
              context.go('/customers');
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
}
