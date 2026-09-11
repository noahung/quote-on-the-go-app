import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../components/brand_mark.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Firebase is initialized before runApp. The router resolves the account;
    // do not hold the user behind a decorative timer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) => const SplashContent();
}

class SplashContent extends StatelessWidget {
  const SplashContent({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const BrandMark(size: 96),
        const SizedBox(height: 24),
        Text('Quote on the Go',
            textAlign: TextAlign.center, style: theme.textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text('Ready for the next job',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2, semanticsLabel: 'Opening your workspace')),
      ]),
    ))));
  }
}
