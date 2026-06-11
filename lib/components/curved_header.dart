import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CurvedHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final bool? showBackButton;
  final VoidCallback? onBackPressed;
  final bool showMenuButton;

  const CurvedHeader({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton,
    this.onBackPressed,
    this.showMenuButton = false,
  });

  VoidCallback _buildBackHandler(BuildContext context) {
    return onBackPressed ?? () {
      try {
        final router = GoRouter.of(context);
        if (router.canPop()) { router.pop(); return; }
      } catch (_) {}
      if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); return; }
      try {
        final p = GoRouterState.of(context).uri.path;
        if (p.startsWith('/quotations')) { context.go('/quotations'); }
        else if (p.startsWith('/invoices')) { context.go('/invoices'); }
        else if (p.startsWith('/customers')) { context.go('/customers'); }
        else if (p.startsWith('/schedule')) { context.go('/schedule'); }
        else if (p.startsWith('/services')) { context.go('/services'); }
        else if (p.startsWith('/expenses')) { context.go('/expenses'); }
        else if (p.startsWith('/collaboration')) { context.go('/quotations'); }
        else { context.go('/'); }
      } catch (_) { Navigator.of(context).pop(); }
    };
  }

  @override
  Widget build(BuildContext context) {
    GoRouterState? state;
    try { state = GoRouterState.of(context); } catch (_) {}

    final path = state?.uri.path;

    // Only the dashboard root uses the curved gradient header
    final isDashboard = path == '/';

    const rootShellPaths = {
      '/', '/quotations', '/invoices', '/customers',
      '/schedule', '/workflows', '/analytics', '/pricing',
    };
    final isRootPath = path != null && rootShellPaths.contains(path);
    final canPop = showBackButton ?? (path != null ? !isRootPath : Navigator.of(context).canPop());
    final shouldShowMenu = showMenuButton || (isRootPath && path != '/');

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
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : colorScheme.primary,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              if (canPop)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _buildBackHandler(context),
                )
              else if (shouldShowMenu)
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    final scaffoldState = Scaffold.maybeOf(context);
                    scaffoldState?.openDrawer();
                  },
                )
              else
                const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actions != null) ...actions!,
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
