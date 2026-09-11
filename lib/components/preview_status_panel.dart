import 'package:flutter/material.dart';

/// Loading and recovery content remains reachable in short, large-text views.
class PreviewStatusPanel extends StatelessWidget {
  const PreviewStatusPanel(
      {super.key, required this.message, this.loading = false, this.onRetry});
  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Semantics(
                  liveRegion: true,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                            child: loading
                                ? const CircularProgressIndicator()
                                : Icon(Icons.description_outlined,
                                    size: 36,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                        const SizedBox(height: 20),
                        Text(message,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge),
                        if (onRetry != null) ...[
                          const SizedBox(height: 20),
                          FilledButton(
                              onPressed: onRetry,
                              child: const Text('Try again')),
                        ],
                      ])))));
}
