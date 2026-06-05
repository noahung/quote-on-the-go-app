import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CurvedHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final bool? showBackButton;
  final VoidCallback? onBackPressed;

  const CurvedHeader({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    GoRouterState? state;
    try {
      state = GoRouterState.of(context);
    } catch (_) {
      // Not in GoRouter tree
    }

    final path = state?.uri.path;
    const rootShellPaths = {
      '/',
      '/quotations',
      '/invoices',
      '/customers',
      '/schedule',
      '/workflows',
      '/analytics',
      '/pricing',
    };
    final isRootPath = path != null && rootShellPaths.contains(path);
    final canPop = showBackButton ?? (path != null ? !isRootPath : Navigator.of(context).canPop());

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: onBackPressed ?? () {
                        try {
                          final router = GoRouter.of(context);
                          if (router.canPop()) {
                            router.pop();
                            return;
                          }
                        } catch (_) {}

                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                          return;
                        }

                        try {
                          final path = GoRouterState.of(context).uri.path;
                          if (path.startsWith('/quotations')) {
                            context.go('/quotations');
                          } else if (path.startsWith('/invoices')) {
                            context.go('/invoices');
                          } else if (path.startsWith('/customers')) {
                            context.go('/customers');
                          } else if (path.startsWith('/schedule')) {
                            context.go('/schedule');
                          } else if (path.startsWith('/services')) {
                            context.go('/services');
                          } else if (path.startsWith('/expenses')) {
                            context.go('/expenses');
                          } else if (path.startsWith('/collaboration')) {
                            context.go('/quotations');
                          } else {
                            context.go('/');
                          }
                        } catch (_) {
                          // Fallback pop
                          Navigator.of(context).pop();
                        }
                      },
                    )
                  else
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
            ],
          ),
        ),
      ),
    );
  }
}
