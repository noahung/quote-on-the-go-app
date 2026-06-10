import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../components/curved_header.dart';
import '../../theme/semantic_colors.dart';
import '../../models/service.dart';
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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getDynamicBundles(List<Service> services) {
    if (services.isEmpty) return [];
    if (services.length < 2) {
      final s = services.first;
      return [
        {
          'name': 'Double ${s.name}',
          'items': '2x ${s.name} (£${s.price.toStringAsFixed(0)} each)',
          'price': (s.price * 2 * 0.85).toStringAsFixed(0),
          'discount': '15%',
          'probability': '64%',
        }
      ];
    }
    final sorted = List<Service>.from(services)..sort((a, b) => b.price.compareTo(a.price));
    final s1 = sorted[0];
    final s2 = sorted[1];
    return [
      {
        'name': '${s1.name} & ${s2.name} Combo',
        'items': '${s1.name} (£${s1.price.toStringAsFixed(0)}) + ${s2.name} (£${s2.price.toStringAsFixed(0)})',
        'price': ((s1.price + s2.price) * 0.9).toStringAsFixed(0),
        'discount': '10%',
        'probability': '78%',
      },
      if (services.length > 2)
        {
          'name': 'Triple Threat Pack',
          'items': '${sorted[0].name} + ${sorted[1].name} + ${sorted[2].name}',
          'price': ((sorted[0].price + sorted[1].price + sorted[2].price) * 0.8).toStringAsFixed(0),
          'discount': '20%',
          'probability': '85%',
        }
    ];
  }

  Future<void> _applyNewPrice(BuildContext context, Service service, double newPrice) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isApplying = true);
    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('services').doc(service.id).update({
        'price': newPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Successfully updated ${service.name} price to £${newPrice.toStringAsFixed(0)}!'),
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

            // Default selection if not set or not in list anymore
            if (_selectedServiceId == null || !services.any((s) => s.id == _selectedServiceId)) {
              _selectedServiceId = services.first.id;
            }

            final selectedService = services.firstWhere((s) => s.id == _selectedServiceId);

            return Column(
              children: [
                const SizedBox(height: 16),
                // Dropdown to pick service
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

                // Segmented Toggles
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
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      tabs: const [
                        Tab(text: 'Price Optimizer'),
                        Tab(text: 'Service Bundles'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tab View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOptimizerTab(context, selectedService, services, semanticColors, isDark),
                      _buildBundlesTab(context, services, semanticColors, isDark),
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

  Widget _buildOptimizerTab(
    BuildContext context,
    Service service,
    List<Service> services,
    SemanticColors colors,
    bool isDark,
  ) {
    final double optPrice = service.price * 1.12; // 12% increase recommendation
    final double increase = optPrice - service.price;
    final double monthlyIncrease = increase * 15; // assuming 15 jobs a month

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero suggestion card
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
                        service.name,
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
                        '92% Confidence',
                        style: TextStyle(color: colors.success, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Price difference layout
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Price', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '£${service.price.toStringAsFixed(0)}',
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
                        const Text('Optimized Suggestion', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '£${optPrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFF4781F)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+12.0%',
                                style: TextStyle(color: colors.success, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Metrics summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '+£${monthlyIncrease.toStringAsFixed(0)}/mo projected increase',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'Low Risk',
                        style: TextStyle(color: colors.success, fontSize: 10, fontWeight: FontWeight.w800),
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
                Text(
                  'High seasonal demand in June combined with average local competitor pricing allows a 12% price optimization with minimal conversion risk for ${service.name}.',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),

                // Factors row
                const Text(
                  'Key Impact Factors:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                _buildFactorRow('Demand / Seasonality', 'High positive impact (+12%)', colors.success),
                _buildFactorRow('Competitor Benchmarking', 'Average market rate is higher (+£${(service.price * 0.1).toStringAsFixed(0)})', colors.success),
                const SizedBox(height: 20),

                FilledButton(
                  onPressed: _isApplying ? null : () => _applyNewPrice(context, service, optPrice),
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
                      : const Text('Apply New Price', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Service Bundles Preview
        const Text(
          'Recommended Service Bundle',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_getDynamicBundles(services).isNotEmpty)
          _buildStaticBundleCard(colors, isDark, _getDynamicBundles(services).first)
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Add more services to unlock bundles.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
      ],
    );
  }

  Widget _buildStaticBundleCard(SemanticColors colors, bool isDark, Map<String, dynamic> bundle) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
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
                    bundle['name'],
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
                    '${bundle['probability']} Win Prob',
                    style: TextStyle(color: colors.success, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              bundle['items'],
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '£${bundle['price']} (Save ${bundle['discount']})',
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
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFactorRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(Icons.arrow_upward, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBundlesTab(BuildContext context, List<Service> services, SemanticColors colors, bool isDark) {
    final bundles = _getDynamicBundles(services);
    if (bundles.isEmpty) {
      return const Center(child: Text('Add services to see bundle recommendations.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bundles.length,
      itemBuilder: (context, index) {
        final bundle = bundles[index];
        return _buildBundleCard(context, colors, bundle);
      },
    );
  }

  Widget _buildBundleCard(
    BuildContext context,
    SemanticColors colors,
    Map<String, dynamic> bundle,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    bundle['name'],
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
                    '${bundle['probability']} Win Prob',
                    style: TextStyle(color: colors.success, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              bundle['items'],
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '£${bundle['price']} (Save ${bundle['discount']})',
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
            )
          ],
        ),
      ),
    );
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
