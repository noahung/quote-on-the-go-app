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

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final company = ref.watch(companyProvider);
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isEffectivelyFreeTier =
        company?.tier == 'free' || company?.tier == null;

    // Update current index based on location
    if (location.startsWith('/quotations')) {
      _currentIndex = 1;
    } else if (location.startsWith('/invoices')) {
      _currentIndex = 2;
    } else if (location.startsWith('/schedule')) {
      _currentIndex = 3;
    } else if (location.startsWith('/customers')) {
      _currentIndex = 4;
    } else {
      _currentIndex = 0;
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent, // Transparent to show global MeshBackground
        body: widget.child,
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
                  NavigationBar(
                    backgroundColor: Colors.transparent, // transparent so the backdrop filter shows through
                    elevation: 0,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
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
                          context.go('/schedule');
                          break;
                        case 4:
                          context.go('/customers');
                          break;
                      }
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: 'Dashboard',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.description_outlined),
                        selectedIcon: Icon(Icons.description),
                        label: 'Quotations',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_outlined),
                        selectedIcon: Icon(Icons.receipt),
                        label: 'Invoices',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.calendar_today_outlined),
                        selectedIcon: Icon(Icons.calendar_today),
                        label: 'Schedule',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.people_outlined),
                        selectedIcon: Icon(Icons.people),
                        label: 'Customers',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
