import 'package:flutter/material.dart';

/// A wrapping, whole-row destination shared by account and settings pages.
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onTap,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 72),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        child: Row(children: [
                          Icon(icon,
                              size: 26, color: theme.colorScheme.onSurface),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w500)),
                                if (subtitle != null &&
                                    subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(subtitle!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              color: theme.colorScheme
                                                  .onSurfaceVariant)),
                                ],
                              ])),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right,
                              size: 26,
                              color: theme.colorScheme.onSurfaceVariant),
                        ]))))));
  }
}

/// Large section titles give settings a clear hierarchy without extra panels.
class SettingsSectionHeading extends StatelessWidget {
  const SettingsSectionHeading(this.title, {super.key, this.first = false});
  final String title;
  final bool first;

  @override
  Widget build(BuildContext context) => Semantics(
      header: true,
      child: Padding(
          padding: EdgeInsets.only(top: first ? 16 : 28, bottom: 18),
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontSize: 32, letterSpacing: -0.8))));
}
