import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final hasLimit = limit != null && limit! > 0;
    final isAtLimit = hasLimit && currentCount >= limit!;
    final isNearLimit = hasLimit && currentCount >= (limit! * 0.8).floor() && !isAtLimit;
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
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
            // Usage indicator for free tier
            if (showUpgradeCta && hasLimit) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isAtLimit
                      ? Colors.red.shade50
                      : isNearLimit
                          ? Colors.amber.shade50
                          : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAtLimit
                        ? Colors.red.shade200
                        : isNearLimit
                            ? Colors.amber.shade200
                            : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Free tier usage',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '$currentCount of $limit $itemName',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isAtLimit
                                ? Colors.red
                                : isNearLimit
                                    ? Colors.amber.shade700
                                    : Colors.grey.shade600,
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
                        backgroundColor: isAtLimit
                            ? Colors.red.shade100
                            : isNearLimit
                                ? Colors.amber.shade100
                                : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isAtLimit
                              ? Colors.red
                              : isNearLimit
                                  ? Colors.amber
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
                        style: TextStyle(
                          fontSize: 11,
                          color: isAtLimit ? Colors.red : Colors.amber.shade700,
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
                icon: const Icon(Icons.workspace_premium, color: Colors.amber),
                label: const Text('Upgrade to Pro'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber.shade700,
                  side: BorderSide(color: Colors.amber.shade200),
                  backgroundColor: Colors.amber.shade50,
                ),
              ),
            ],
            // Premium badge for premium users
            if (isPremium) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade100, Colors.orange.shade100],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      size: 16,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Premium Plan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade700,
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
