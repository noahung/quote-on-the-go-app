import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CurvedHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final bool? showBackButton;
  final VoidCallback? onBackPressed;
  final bool showMenuButton;
  final VoidCallback? onMenuPressed;

  const CurvedHeader({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton,
    this.onBackPressed,
    this.showMenuButton = false,
    this.onMenuPressed,
  });

  VoidCallback _buildBackHandler(BuildContext context) {
    return onBackPressed ?? () {
      try {
        final router = GoRouter.of(context);
        if (router.canPop()) { router.pop(); return; }
      } catch (_) {}
      if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); return; }
      // For screens that can't pop (like drawer screens), go to Dashboard
      context.go('/');
    };
  }

  @override
  Widget build(BuildContext context) {
    GoRouterState? state;
    try { state = GoRouterState.of(context); } catch (_) {}

    final path = state?.uri.path;

    // Only the dashboard root uses the curved gradient header
    final isDashboard = path == '/';

    // Bottom nav root paths (Dashboard, Schedule, Customers, Settings)
    const bottomNavPaths = {'/', '/schedule', '/customers', '/settings'};
    // Drawer-accessed paths should show back button, not menu
    const drawerPaths = {
      '/quotations', '/invoices', '/workflows', '/analytics',
      '/pipeline', '/services', '/expenses',
    };
    final isBottomNavPath = path != null && bottomNavPaths.contains(path);
    final isDrawerPath = path != null && drawerPaths.any((p) => path.startsWith(p));
    final canPop = showBackButton ?? (isDrawerPath || (path != null && !isBottomNavPath));
    final shouldShowMenu = showMenuButton || isBottomNavPath;

    if (isDashboard) {
      // ── Curved gradient header (dashboard only) ──
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B00), Color(0xFFF4781F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 36, left: 8, right: 8),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      );
    }

    // ── Simple flat AppBar for all other screens ──
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: Colors.transparent, // Fully transparent to let Mesh background flow
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            height: 64, // Slightly taller for premium breathing room
            child: Row(
              children: [
                if (canPop)
                  IconButton(
                    icon: Icon(LucideIcons.arrowLeft, color: colorScheme.onSurface),
                    onPressed: _buildBackHandler(context),
                  )
                else if (shouldShowMenu)
                  IconButton(
                    icon: Icon(LucideIcons.menu, color: colorScheme.onSurface),
                    onPressed: onMenuPressed ?? () {
                      final scaffoldState = Scaffold.maybeOf(context);
                      scaffoldState?.openDrawer();
                    },
                  )
                else
                  const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actions != null)
                  IconTheme(
                    data: IconThemeData(color: colorScheme.onSurface),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
