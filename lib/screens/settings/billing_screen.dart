import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/providers.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../components/curved_header.dart';
import '../../theme/semantic_colors.dart';
import '../team/team_management_screen.dart';

const String _webAppBaseUrl = 'https://app.quoteonthego.co.uk';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  bool _isLoading = false;

  Future<void> _handleUpgrade(String planType) async {
    final company = ref.read(companyProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (company == null || user == null) return;

    setState(() => _isLoading = true);
    try {
      final idToken = await user.getIdToken();
      final bool isPremium = (company.tier == 'premium' || company.tier == 'individual' || company.tier == 'organisation') &&
          (company.subscriptionStatus == 'active' ||
              company.subscriptionStatus == 'referral_trial');

      String? redirectUrl;

      if (isPremium) {
        if (company.stripeCustomerId == null) {
          throw Exception('No Stripe customer found. Contact support.');
        }
        final response = await http.post(
          Uri.parse('$_webAppBaseUrl/api/stripe/create-customer-portal-session'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'stripeCustomerId': company.stripeCustomerId}),
        );
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode != 200) {
          throw Exception(data['error'] ?? 'Failed to open portal.');
        }
        redirectUrl = data['url'] as String?;
      } else {
        final response = await http.post(
          Uri.parse('$_webAppBaseUrl/api/stripe/create-checkout-session'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'companyId': company.id,
            'userEmail': user.email,
            'planType': planType,
          }),
        );
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode != 200) {
          throw Exception(data['error'] ?? 'Failed to create checkout.');
        }
        redirectUrl = data['url'] as String?;
      }

      if (redirectUrl != null) {
        final uri = Uri.parse(redirectUrl);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw Exception('Could not open browser.');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(companyProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tier = company?.tier ?? 'free';
    final isPremium = (tier == 'premium' || tier == 'individual' || tier == 'organisation') &&
        (company?.subscriptionStatus == 'active' ||
            company?.subscriptionStatus == 'referral_trial');
    final isReferralTrial = company?.subscriptionStatus == 'referral_trial';

    int activeMembers = 0;
    int pendingInvitations = 0;
    
    if (tier == 'organisation') {
      final teamAsync = ref.watch(teamMembersProvider);
      final pendingAsync = ref.watch(pendingInvitationsProvider);
      
      activeMembers = teamAsync.valueOrNull?.length ?? 0;
      pendingInvitations = pendingAsync.valueOrNull?.length ?? 0;
    }
    
    final totalSeats = activeMembers + pendingInvitations;
    final extraSeats = (totalSeats - 1).clamp(0, 999999);
    const double baseCost = 29.00;
    const double perSeatCost = 4.99;
    final double totalMonthlyCost = baseCost + (extraSeats * perSeatCost);

    String planDisplayName = 'Starter (Free)';
    IconData planIcon = LucideIcons.user;
    Color planIconColor = Colors.grey;
    if (tier == 'organisation') {
      planDisplayName = 'Organisation';
      planIcon = LucideIcons.building2;
      planIconColor = Colors.orange;
    } else if (tier == 'individual') {
      planDisplayName = 'Individual';
      planIcon = LucideIcons.user;
      planIconColor = Colors.blue;
    } else if (tier == 'premium') {
      planDisplayName = 'Pro';
      planIcon = LucideIcons.crown;
      planIconColor = Colors.amber;
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const CurvedHeader(title: 'Plans & Billing'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Current Plan badge
                  if (company != null) ...[
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: planIconColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  planIcon,
                                  color: planIconColor,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$planDisplayName Plan',
                                      style: const TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isPremium
                                          ? 'All features unlocked'
                                          : 'Limited features',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.6)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPremium
                                      ? semanticColors.success.withValues(alpha: 0.12)
                                      : Colors.grey.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  isPremium ? 'Active' : 'Free',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isPremium ? semanticColors.success : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isPremium) ...[
                            const SizedBox(height: 16),
                            Divider(
                              height: 1,
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                            ),
                            const SizedBox(height: 16),
                            if (isReferralTrial && company.trialEndsAt != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  '⏱ Free trial from referral — expires on ${company.trialEndsAt!.day}/${company.trialEndsAt!.month}/${company.trialEndsAt!.year}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange),
                                ),
                              ),
                            if (tier == 'organisation') ...[
                              const Text(
                                'MONTHLY BREAKDOWN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Base plan (1 seat included)', style: TextStyle(fontSize: 13)),
                                  Text('£${baseCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              if (extraSeats > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Extra seats ($extraSeats × £${perSeatCost.toStringAsFixed(2)})', style: const TextStyle(fontSize: 13)),
                                    Text('£${(extraSeats * perSeatCost).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total per month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('£${totalMonthlyCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(LucideIcons.users, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$activeMembers active ${activeMembers == 1 ? "member" : "members"}',
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                                  ),
                                  if (pendingInvitations > 0) ...[
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(color: colorScheme.onSurface.withValues(alpha: 0.3), shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '$pendingInvitations pending ${pendingInvitations == 1 ? "invitation" : "invitations"}',
                                      style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                                    ),
                                  ],
                                ],
                              ),
                            ] else ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text('Monthly cost', style: TextStyle(fontSize: 14)),
                                  Text('£29.00', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Single-user plan with unlimited invoices and quotations.',
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Plan Options List
                  _PlanCard(
                    name: 'Starter (Free)',
                    price: '£0',
                    period: 'forever',
                    features: const [
                      'Up to 5 quotations/month',
                      'Up to 3 invoices/month',
                      'Basic customer management',
                      'Email support',
                    ],
                    isCurrentPlan: tier == 'free',
                    isDark: isDark,
                    colorScheme: colorScheme,
                    ctaLabel: tier == 'free' ? 'Current Plan' : null,
                    ctaEnabled: false,
                  ),
                  const SizedBox(height: 16),

                  _PlanCard(
                    name: 'Individual',
                    price: '£29',
                    period: 'per month',
                    features: const [
                      'Unlimited quotations & invoices',
                      'Smart Pricing & AI suggestions',
                      'Workflow automations',
                      'Advanced analytics',
                      'Single-user workspace limit',
                      'QuickBooks & Monday.com integrations',
                      'Priority support',
                    ],
                    isCurrentPlan: tier == 'individual' || tier == 'premium',
                    isDark: isDark,
                    colorScheme: colorScheme,
                    ctaLabel: (tier == 'individual' || tier == 'premium')
                        ? 'Manage Subscription'
                        : 'Get Individual',
                    ctaEnabled: true,
                    isLoading: _isLoading,
                    onTap: () => _handleUpgrade('individual'),
                  ),
                  const SizedBox(height: 16),

                  _PlanCard(
                    name: 'Organisation',
                    price: '£29',
                    period: 'base seat + £4.99/seat',
                    features: const [
                      'Everything in Individual, plus:',
                      'Multi-user team access',
                      'Approval workflows & permissions',
                      'Real-time team collaboration sidebar',
                      'Team activity audit trails',
                    ],
                    isCurrentPlan: tier == 'organisation',
                    isDark: isDark,
                    colorScheme: colorScheme,
                    isPrimary: true,
                    ctaLabel: tier == 'organisation'
                        ? 'Manage Subscription'
                        : 'Get Organisation',
                    ctaEnabled: true,
                    isLoading: _isLoading,
                    onTap: () => _handleUpgrade('organisation'),
                  ),
                  const SizedBox(height: 24),

            // FAQ
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _FaqTile(
              question: 'Can I cancel anytime?',
              answer:
                  'Yes. You can cancel your subscription at any time from the Stripe customer portal. Your access continues until the end of the billing period.',
              isDark: isDark,
            ),
            _FaqTile(
              question: 'What happens to my data if I downgrade?',
              answer:
                  'All your data is preserved. You just lose access to Pro features, but can upgrade again at any time.',
              isDark: isDark,
            ),
            _FaqTile(
              question: 'Is there a free trial?',
              answer:
                  'Yes — refer a friend who upgrades and you both get 1 month free. Use the Referral Programme in Settings.',
              isDark: isDark,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ],
  ),
),
);
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String period;
  final List<String> features;
  final bool isCurrentPlan;
  final bool isPrimary;
  final bool isDark;
  final ColorScheme colorScheme;
  final String? ctaLabel;
  final bool ctaEnabled;
  final bool isLoading;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    required this.isCurrentPlan,
    required this.isDark,
    required this.colorScheme,
    this.isPrimary = false,
    this.ctaLabel,
    this.ctaEnabled = true,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isPrimary
        ? const Color(0xFFF4781F)
        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06));

    return Container(
      decoration: BoxDecoration(
        color: isPrimary
            ? const Color(0xFFF4781F).withValues(alpha: isDark ? 0.08 : 0.04)
            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: isPrimary ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isPrimary ? const Color(0xFFF4781F) : null,
                  ),
                ),
                if (isPrimary)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4781F).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'POPULAR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF4781F),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: price,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: isPrimary
                          ? const Color(0xFFF4781F)
                          : colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: ' / $period',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle,
                          size: 18,
                          color: isPrimary
                              ? const Color(0xFFF4781F)
                              : Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(f,
                            style: const TextStyle(
                                fontSize: 14, height: 1.3)),
                      ),
                    ],
                  ),
                )),
            if (ctaLabel != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: isPrimary
                    ? FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF4781F),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                        onPressed:
                            (ctaEnabled && !isLoading) ? onTap : null,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(ctaLabel!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                      )
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: ctaEnabled ? onTap : null,
                        child: Text(ctaLabel!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  final bool isDark;

  const _FaqTile({
    required this.question,
    required this.answer,
    required this.isDark,
  });

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? Colors.white10
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.question,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            trailing: Icon(
                _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Text(
                widget.answer,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                    height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
