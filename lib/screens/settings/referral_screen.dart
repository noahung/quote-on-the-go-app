import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/providers.dart';
import '../../providers/auth_provider.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../components/curved_header.dart';

final referralStatsProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final userProfile = ref.watch(userProfileProvider);
  if (userProfile == null) return const Stream.empty();

  final referralCode = userProfile.uid.substring(0, 8).toUpperCase();

  return FirebaseFirestore.instance
      .collection('users')
      .where('referredBy', isEqualTo: referralCode)
      .snapshots()
      .map((snap) {
    final referred = snap.docs.map((d) => d.data()).toList();
    final converted = referred
        .where((u) => u['tier'] == 'premium' || u['tier'] == 'pro')
        .length;
    return {
      'referralCode': referralCode,
      'referralCount': referred.length,
      'convertedCount': converted,
      'referred': referred,
    };
  });
});

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(referralStatsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const CurvedHeader(title: 'Referral Programme'),
            Expanded(
              child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (stats) {
            final referralCode = stats['referralCode'] as String;
            final referralCount = stats['referralCount'] as int;
            final convertedCount = stats['convertedCount'] as int;
            final referred = stats['referred'] as List<Map<String, dynamic>>;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Hero banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF4781F), Color(0xFFFF9845)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.card_giftcard,
                          color: Colors.white, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Earn 1 Month Free',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'For every friend who upgrades to Pro, you both get 1 month free!',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Total Referred',
                        value: '$referralCount',
                        icon: LucideIcons.users,
                        color: colorScheme.primary,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Converted',
                        value: '$convertedCount',
                        icon: LucideIcons.star,
                        color: Colors.green,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Months Earned',
                        value: '$convertedCount',
                        icon: LucideIcons.calendarDays,
                        color: Colors.purple,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Referral link
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Referral Link',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'https://app.quoteonthego.co.uk/register?ref=$referralCode',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                    text:
                                        'https://app.quoteonthego.co.uk/register?ref=$referralCode'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Referral link copied to clipboard!')),
                                );
                              },
                              icon: Icon(Icons.copy_outlined,
                                  color: colorScheme.primary),
                              tooltip: 'Copy link',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Your code',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.5))),
                                const SizedBox(height: 2),
                                Text(
                                  referralCode,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.primary,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: referralCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Code copied!')),
                              );
                            },
                            icon: const Icon(Icons.copy_outlined, size: 16),
                            label: const Text('Copy Code'),
                            style: OutlinedButton.styleFrom(
                              side:
                                  BorderSide(color: colorScheme.primary),
                              foregroundColor: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Referred users
                if (referred.isNotEmpty) ...[
                  const Text(
                    'Your Referrals',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...referred.map((user) {
                    final email = user['email'] as String? ?? 'Unknown';
                    final name = user['displayName'] as String?;
                    final tier = user['tier'] as String? ?? 'free';
                    final isConverted = tier == 'premium' || tier == 'pro';
                    return GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isConverted
                                ? Colors.green.withValues(alpha: 0.15)
                                : colorScheme.primaryContainer
                                    .withValues(alpha: 0.15),
                            child: Text(
                              (name ?? email)[0].toUpperCase(),
                              style: TextStyle(
                                  color: isConverted
                                      ? Colors.green
                                      : colorScheme.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name ?? email,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (name != null)
                                  Text(
                                    email,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.5)),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isConverted
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              isConverted ? 'Converted' : 'Free Plan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color:
                                    isConverted ? Colors.green : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  GlassCard(
                    child: Column(
                      children: [
                        Icon(Icons.people_outline,
                            size: 48, color: colorScheme.outline),
                        const SizedBox(height: 12),
                        const Text(
                          'No referrals yet',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share your link and start earning free months!',
                          style: TextStyle(color: colorScheme.outline),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    ],
  ),
),
);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
