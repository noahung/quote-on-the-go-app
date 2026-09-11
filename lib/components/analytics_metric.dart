import 'package:flutter/material.dart';

class AnalyticsMetric extends StatelessWidget {
  const AnalyticsMetric(
      {super.key,
      required this.title,
      required this.value,
      required this.subtitle});
  final String title, value, subtitle;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(subtitle,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]));
  }
}
