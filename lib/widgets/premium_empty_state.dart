import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PremiumEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isPremium;
  final int currentCount;
  final int? limit;
  final String itemName;
  final bool showUpgradeCta;
  final VoidCallback? onUpgrade;

  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.isPremium = false,
    this.currentCount = 0,
    this.limit,
    this.itemName = 'items',
    this.showUpgradeCta = false,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasLimit = limit != null && limit! > 0;
    final isAtLimit = hasLimit && currentCount >= limit!;
    final isNearLimit =
        hasLimit && currentCount >= (limit! * 0.8).floor() && !isAtLimit;
    final usagePercent = hasLimit ? (currentCount / limit!) : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
            // Usage indicator for free tier
            if (showUpgradeCta && hasLimit) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isAtLimit
                      ? colorScheme.error.withValues(alpha: 0.06)
                      : isNearLimit
                          ? colorScheme.primary.withValues(alpha: 0.06)
                          : colorScheme.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAtLimit
                        ? colorScheme.error.withValues(alpha: 0.2)
                        : isNearLimit
                            ? colorScheme.primary.withValues(alpha: 0.2)
                            : colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Free tier usage',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '$currentCount of $limit $itemName',
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isAtLimit
                                ? colorScheme.error
                                : isNearLimit
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: usagePercent,
                        minHeight: 6,
                        backgroundColor:
                            colorScheme.onSurface.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isAtLimit
                              ? colorScheme.error
                              : isNearLimit
                                  ? colorScheme.primary
                                  : colorScheme.primary,
                        ),
                      ),
                    ),
                    if (isAtLimit || isNearLimit) ...[
                      const SizedBox(height: 8),
                      Text(
                        isAtLimit
                            ? 'You\'ve reached your limit. Upgrade to create more.'
                            : 'You\'re approaching your limit. Upgrade for unlimited $itemName.',
                        textAlign: TextAlign.center,
                        style: textTheme.labelSmall?.copyWith(
                          color: isAtLimit
                              ? colorScheme.error
                              : colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Action button
            if (actionLabel != null && onAction != null)
              FilledButton.icon(
                onPressed: isAtLimit && !isPremium ? null : onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            // Upgrade CTA
            if (showUpgradeCta && !isPremium && (isNearLimit || isAtLimit)) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onUpgrade,
                icon: Icon(LucideIcons.crown, color: colorScheme.primary),
                label: const Text('Upgrade to Pro'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.4)),
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.05),
                ),
              ),
            ],
            // Premium badge for premium users
            if (isPremium) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.crown,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Premium Plan',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
