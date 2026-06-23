import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../components/curved_header.dart';
import '../../theme/semantic_colors.dart';
import '../../providers/providers.dart';

class SmartPricingScreen extends ConsumerStatefulWidget {
  const SmartPricingScreen({super.key});

  @override
  ConsumerState<SmartPricingScreen> createState() => _SmartPricingScreenState();
}

class _SmartPricingScreenState extends ConsumerState<SmartPricingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedServiceId;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _applyNewPrice(BuildContext context, String serviceId, String serviceName, double newPrice) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isApplying = true);
    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('services').doc(serviceId).update({
        'price': newPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Updated $serviceName price to £${newPrice.toStringAsFixed(0)}!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update price: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final servicesAsync = ref.watch(servicesStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          CurvedHeader(title: 'Smart Pricing'),
          Expanded(
            child: servicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error loading services: $err')),
          data: (services) {
            if (services.isEmpty) {
              return _buildEmptyState(context);
            }

            if (_selectedServiceId == null || !services.any((s) => s.id == _selectedServiceId)) {
              _selectedServiceId = services.first.id;
            }

            return Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedServiceId,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        hint: const Text('Select Service to Optimize'),
                        items: services.map((s) {
                          return DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(
                              s.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedServiceId = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      indicatorColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: isDark ? const Color(0xFFF4781F).withValues(alpha: 0.15) : const Color(0xFFF4781F).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: const Color(0xFFF4781F),
                      unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      tabs: const [
                        Tab(text: 'Optimizer'),
                        Tab(text: 'Bundles'),
                        Tab(text: 'Discounts'),
                        Tab(text: 'Receipt'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOptimizerTab(context, semanticColors, isDark),
                      _buildBundlesTab(context, semanticColors, isDark),
                      _buildDiscountsTab(context, semanticColors, isDark),
                      _buildReceiptTab(context, semanticColors, isDark),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizerTab(BuildContext context, SemanticColors colors, bool isDark) {
    final suggestionsAsync = ref.watch(pricingSuggestionsProvider(_selectedServiceId));

    return suggestionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Failed to load suggestions: $err', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(pricingSuggestionsProvider(_selectedServiceId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (suggestions) {
        if (suggestions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.insights, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Not enough data yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Create at least 3 quotations for a service to unlock AI-powered pricing insights.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final suggestion = _selectedServiceId != null
            ? suggestions.where((s) => s['serviceId'] == _selectedServiceId).firstOrNull
            : suggestions.firstOrNull;

        if (suggestion == null) {
          return const Center(child: Text('No suggestion for this service.', style: TextStyle(color: Colors.grey)));
        }

        return _buildSuggestionCard(context, suggestion, colors, isDark);
      },
    );
  }

  Widget _buildSuggestionCard(BuildContext context, Map<String, dynamic> suggestion, SemanticColors colors, bool isDark) {
    final serviceName = suggestion['serviceName'] as String? ?? 'Unknown';
    final suggestedPrice = (suggestion['suggestedPrice'] as num?)?.toDouble() ?? 0;
    final currentPrice = (suggestion['currentPrice'] as num?)?.toDouble() ?? 0;
    final confidence = (suggestion['confidence'] as num?)?.toDouble() ?? 0.5;
    final reasoning = suggestion['reasoning'] as String? ?? '';
    final factors = (suggestion['factors'] as List<dynamic>?) ?? [];
    final serviceId = suggestion['serviceId'] as String? ?? '';

    final priceDiff = suggestedPrice - currentPrice;
    final percentChange = currentPrice > 0 ? (priceDiff / currentPrice) * 100 : 0.0;
    final isIncrease = priceDiff >= 0;

    final historical = suggestion['historicalPerformance'] as Map<String, dynamic>?;
    final revenueImpact = historical?['revenueImpact'] as Map<String, dynamic>?;
    final riskLevel = revenueImpact?['riskLevel'] as String? ?? 'low';
    final projectedIncrease = (revenueImpact?['projectedIncrease'] as num?)?.toDouble() ?? 0;

    final riskColor = riskLevel == 'high'
        ? colors.error
        : riskLevel == 'medium'
            ? Colors.amber
            : colors.success;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        serviceName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(confidence * 100).toStringAsFixed(0)}% Confidence',
                        style: TextStyle(color: colors.success, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Price', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '£${currentPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            decoration: TextDecoration.lineThrough,
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Icon(Icons.arrow_forward, color: Color(0xFFF4781F), size: 24),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Suggested', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '£${suggestedPrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFF4781F)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isIncrease ? colors.success : colors.error).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${isIncrease ? '+' : ''}${percentChange.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: isIncrease ? colors.success : colors.error,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${projectedIncrease >= 0 ? '+' : ''}${projectedIncrease.toStringAsFixed(0)}% projected revenue impact',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${riskLevel[0].toUpperCase()}${riskLevel.substring(1)} Risk',
                        style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'AI Reasoning:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF4781F)),
                ),
                const SizedBox(height: 6),
                Text(reasoning, style: const TextStyle(fontSize: 12, height: 1.4)),
                const SizedBox(height: 16),
                if (factors.isNotEmpty) ...[
                  const Text('Key Impact Factors:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  ...factors.map((f) {
                    final factor = f as Map<String, dynamic>;
                    final impact = factor['impact'] as String? ?? 'neutral';
                    final desc = factor['description'] as String? ?? '';
                    final factorColor = impact == 'increase'
                        ? colors.success
                        : impact == 'decrease'
                            ? colors.error
                            : Colors.grey;
                    return _buildFactorRow(desc, impact, factorColor);
                  }),
                  const SizedBox(height: 20),
                ],
                FilledButton(
                  onPressed: _isApplying ? null : () => _applyNewPrice(context, serviceId, serviceName, suggestedPrice),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF4781F),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _isApplying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Apply Suggested Price', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFactorRow(String label, String impact, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            impact == 'increase' ? Icons.arrow_upward : impact == 'decrease' ? Icons.arrow_downward : Icons.remove,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBundlesTab(BuildContext context, SemanticColors colors, bool isDark) {
    final bundlesAsync = ref.watch(serviceBundlesProvider);

    return bundlesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Failed to load bundles: $err', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(serviceBundlesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (bundles) {
        if (bundles.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.layers, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No bundles yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'Create more quotations with multiple services to unlock bundle recommendations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bundles.length,
          itemBuilder: (context, index) {
            final bundle = bundles[index];
            return _buildBundleCard(colors, isDark, bundle);
          },
        );
      },
    );
  }

  Widget _buildBundleCard(SemanticColors colors, bool isDark, Map<String, dynamic> bundle) {
    final name = bundle['name'] as String? ?? 'Bundle';
    final description = bundle['description'] as String? ?? '';
    final totalPrice = (bundle['totalPrice'] as num?)?.toDouble() ?? 0;
    final discountPercentage = (bundle['discountPercentage'] as num?)?.toDouble() ?? 0;
    final acceptanceRate = (bundle['expectedAcceptanceRate'] as num?)?.toDouble() ?? 0;
    final reasoning = bundle['reasoning'] as String? ?? '';
    final services = (bundle['services'] as List<dynamic>?) ?? [];

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(acceptanceRate * 100).toStringAsFixed(0)}% Win Prob',
                    style: TextStyle(color: colors.success, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (services.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...services.map((s) {
                final svc = s as Map<String, dynamic>;
                final svcName = svc['serviceName'] as String? ?? '';
                final individual = (svc['individualPrice'] as num?)?.toDouble() ?? 0;
                final bundlePrice = (svc['bundlePrice'] as num?)?.toDouble() ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('  • $svcName', style: const TextStyle(fontSize: 12)),
                      Text(
                        '£${individual.toStringAsFixed(0)} -> £${bundlePrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '£${totalPrice.toStringAsFixed(0)} (Save ${discountPercentage.toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFF4781F)),
                ),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF4781F)),
                    foregroundColor: const Color(0xFFF4781F),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Create Bundle'),
                ),
              ],
            ),
            if (reasoning.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(reasoning, style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountsTab(BuildContext context, SemanticColors colors, bool isDark) {
    final quotationsAsync = ref.watch(quotationsStreamProvider);

    return quotationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (quotations) {
        final sentQuotes = quotations.where((q) => q.status == 'Sent').toList();

        if (sentQuotes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.percent, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No sent quotations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'Send quotations to unlock AI-powered discount recommendations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sentQuotes.length,
          itemBuilder: (context, index) {
            final quote = sentQuotes[index];
            return _buildDiscountCard(context, quote, colors, isDark);
          },
        );
      },
    );
  }

  Widget _buildDiscountCard(BuildContext context, dynamic quotation, SemanticColors colors, bool isDark) {
    final recommendationAsync = ref.watch(discountRecommendationProvider(quotation.id));

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${quotation.quotationNumber ?? quotation.id.substring(0, 8)} - ${quotation.customerName ?? 'Unknown'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '£${(quotation.total ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFF4781F)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            recommendationAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
              error: (err, stack) => Text('Failed: $err', style: TextStyle(fontSize: 12, color: colors.error)),
              data: (rec) {
                if (rec == null) {
                  return const Text(
                    'No discount recommendation for this quotation.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  );
                }

                final type = rec['recommendationType'] as String? ?? 'unknown';
                final discountValue = (rec['discountValue'] as num?)?.toDouble() ?? 0;
                final reasoning = rec['reasoning'] as String? ?? '';
                final currentProb = (rec['currentWinProbability'] as num?)?.toDouble() ?? 0;
                final projectedProb = (rec['projectedWinProbability'] as num?)?.toDouble() ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4781F).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${type.replaceAll('_', ' ').toUpperCase()} - ${discountValue.toStringAsFixed(0)}%',
                            style: const TextStyle(color: Color(0xFFF4781F), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(reasoning, style: const TextStyle(fontSize: 12, height: 1.4)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Win prob: ${(currentProb * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const Icon(Icons.arrow_forward, size: 14, color: Color(0xFFF4781F)),
                        Text(
                          '${(projectedProb * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.success),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptTab(BuildContext context, SemanticColors colors, bool isDark) {
    return _ReceiptAnalyzer(colors: colors, isDark: isDark);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No services available for optimization',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please add services in the Services section to see smart pricing insights.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push('/services'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4781F),
              ),
              child: const Text('Go to Services'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptAnalyzer extends ConsumerStatefulWidget {
  final SemanticColors colors;
  final bool isDark;

  const _ReceiptAnalyzer({required this.colors, required this.isDark});

  @override
  ConsumerState<_ReceiptAnalyzer> createState() => _ReceiptAnalyzerState();
}

class _ReceiptAnalyzerState extends ConsumerState<_ReceiptAnalyzer> {
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _pickAndAnalyze() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isAnalyzing = true;
      _error = null;
      _result = null;
    });

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        if (mounted) setState(() => _isAnalyzing = false);
        return;
      }

      final bytes = await image.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final service = ref.read(pricingServiceProvider);
      final result = await service.analyzeReceipt(imageBase64: base64Image);

      if (mounted) {
        setState(() {
          _result = result;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isAnalyzing = false;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to analyze receipt: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Analyzing receipt...', style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ));
    }

    if (_result != null) {
      final merchant = _result!['merchant'] as String? ?? 'Unknown';
      final date = _result!['date'] as String? ?? '';
      final amount = (_result!['amount'] as num?)?.toDouble() ?? 0;
      final currency = _result!['currency'] as String? ?? 'GBP';
      final description = _result!['description'] as String? ?? '';
      final category = _result!['category'] as String? ?? 'Other';

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Color(0xFFF4781F), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(merchant, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ReceiptDetailRow(label: 'Date', value: date),
                  _ReceiptDetailRow(label: 'Amount', value: '$currency$amount'),
                  _ReceiptDetailRow(label: 'Category', value: category),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Description:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(description, style: const TextStyle(fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _pickAndAnalyze,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF4781F),
                          ),
                          child: const Text('Analyze Another'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('AI Receipt Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Upload a receipt image and AI will extract merchant, date, amount, and category automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickAndAnalyze,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Receipt'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4781F),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(fontSize: 12, color: widget.colors.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReceiptDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
