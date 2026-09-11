import 'package:flutter/material.dart';
import 'brand_mark.dart';

class AuthPage extends StatelessWidget {
  const AuthPage(
      {super.key,
      required this.title,
      required this.description,
      required this.children,
      this.onBack,
      this.error});
  final String title, description;
  final List<Widget> children;
  final VoidCallback? onBack;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
        body: SafeArea(
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (onBack != null)
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: IconButton(
                                        tooltip: 'Back',
                                        onPressed: onBack,
                                        icon: const Icon(Icons.arrow_back))),
                              const SizedBox(height: 24),
                              Row(children: [
                                const BrandMark(),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text('Quote on the Go',
                                        style: theme.textTheme.titleMedium))
                              ]),
                              const SizedBox(height: 32),
                              Text(title, style: theme.textTheme.headlineLarge),
                              const SizedBox(height: 12),
                              Text(description,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 32),
                              if (error != null) ...[
                                Semantics(
                                    liveRegion: true,
                                    child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme.errorContainer,
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                        child: Text(error!,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                    color: theme.colorScheme
                                                        .onErrorContainer)))),
                                const SizedBox(height: 24),
                              ],
                              ...children,
                            ]))))));
  }
}

String? validateAuthEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter your email address.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()))
    return 'Enter a valid email address.';
  return null;
}
