import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../components/mesh_background.dart';
import '../../theme/semantic_colors.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDateRange = '90 Days';

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

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFFF6B00), const Color(0xFFF4781F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    if (!const {'/', '/quotations', '/invoices', '/customers', '/schedule', '/workflows', '/analytics', '/pricing'}.contains(GoRouterState.of(context).uri.path) && GoRouter.of(context).canPop())
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => GoRouter.of(context).pop(),
                      ),
                    const Expanded(
                      child: Text(
                        'Advanced Analytics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date Range Selection Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['30 Days', '90 Days', '6 Months', '1 Year'].map((range) {
                  final isSelected = _selectedDateRange == range;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        range,
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFF4781F),
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                      shape: const StadiumBorder(),
                      side: BorderSide.none,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedDateRange = range;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Hero Metric Cards (Horizontal Scrolling)
            SizedBox(
              height: 130,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildMetricCard(
                    context,
                    title: 'Avg. Profit Margin',
                    value: '68.4%',
                    subtitle: 'Total Revenue: £245k',
                    icon: Icons.trending_up,
                    iconColor: semanticColors.success,
                    bgColor: const Color(0xFFF4781F),
                    textColor: Colors.white,
                    useGradient: true,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Pipeline Value',
                    value: '£185,400',
                    subtitle: 'Projected: £120.5k',
                    icon: Icons.track_changes,
                    iconColor: Colors.blueAccent,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Avg. Customer LTV',
                    value: '£12,500',
                    subtitle: 'High-value clients: 18',
                    icon: Icons.people,
                    iconColor: Colors.purpleAccent,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Avg. Response Time',
                    value: '3.4h',
                    subtitle: 'Fast response rate: 92.5%',
                    icon: Icons.hourglass_top,
                    iconColor: Colors.orangeAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Segmented Tabs
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFF4781F),
                labelColor: const Color(0xFFF4781F),
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                tabs: const [
                  Tab(text: 'Profit'),
                  Tab(text: 'Pipeline'),
                  Tab(text: 'LTV'),
                  Tab(text: 'Insights'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Content Wrapper
            SizedBox(
              height: 380,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProfitTab(context, semanticColors, isDark),
                  _buildPipelineTab(context, isDark),
                  _buildLtvTab(context, isDark),
                  _buildInsightsTab(context, semanticColors, isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Business Insights (AI Suggestions) at the bottom
            Card(
              elevation: 0,
              color: const Color(0xFFF4781F).withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: const Color(0xFFF4781F).withValues(alpha: 0.15)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.insights, color: const Color(0xFFF4781F)),
                        const SizedBox(width: 8),
                        const Text(
                          'AI Business Insights',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF4781F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInsightRow(
                      context,
                      title: 'Seasonal Demand Pricing',
                      desc: 'Increase standard painting rates by 12% in July due to peak historical seasonal demand.',
                      priority: 'HIGH',
                      priorityColor: semanticColors.success,
                    ),
                    const Divider(height: 24, color: Colors.black12),
                    _buildInsightRow(
                      context,
                      title: 'Service Bundling Opportunity',
                      desc: 'Offering drywall repair with interior painting boosts average quotation value by 15%.',
                      priority: 'MED',
                      priorityColor: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Color? bgColor,
    Color? textColor,
    bool useGradient = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: useGradient ? Colors.white24 : iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: useGradient ? Colors.white : iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: textColor?.withValues(alpha: 0.8) ?? (isDark ? Colors.white54 : Colors.black45),
            ),
          ),
        ],
      ),
    );

    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: useGradient ? null : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
        gradient: useGradient
            ? LinearGradient(
                colors: [bgColor ?? const Color(0xFFF4781F), const Color(0xFFFF8F00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: useGradient
            ? null
            : Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: content,
    );
  }

  Widget _buildProfitTab(BuildContext context, SemanticColors colors, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Profitability',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _buildProfitItem('Residential Painting', 0.72, '£120k Rev', '£86k Profit', colors.accentPrimary),
            const SizedBox(height: 16),
            _buildProfitItem('Commercial Drywall', 0.58, '£85k Rev', '£49k Profit', isDark ? Colors.white38 : Colors.grey),
            const SizedBox(height: 16),
            _buildProfitItem('Plumbing Repairs', 0.65, '£40k Rev', '£26k Profit', Colors.blue),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('May Trend Profit: £45,200', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'June Profit: £58,400 (71%)',
                    style: TextStyle(color: colors.success, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfitItem(String name, double percent, String rev, String profit, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('${(percent * 100).toInt()}% margin', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(rev, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(profit, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildPipelineTab(BuildContext context, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Funnel (Pipeline)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _buildPipelineItem('Draft', '5 Quotes', 'Value: £15,000', 0.2),
            _buildPipelineItem('Sent', '12 Quotes', 'Value: £48,000', 0.5),
            _buildPipelineItem('Accepted', '28 Quotes', 'Value: £122,400', 0.9),
            const Spacer(),
            const Divider(),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Conversion Rate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('72.5% (Sent → Accepted)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineItem(String stage, String count, String value, double percent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(stage, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 12,
                    backgroundColor: Colors.black12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF4781F)),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(count, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(value, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLtvTab(BuildContext context, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Client Segments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _buildLtvRow('High-Value Clients', '18 clients', '£150,000 total', Colors.orange),
            _buildLtvRow('Medium-Value Clients', '42 clients', '£75,000 total', Colors.blue),
            _buildLtvRow('Low-Value Clients', '25 clients', '£20,000 total', Colors.grey),
            _buildLtvRow('Churned / Inactive', '8 clients', '£0 recent', Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildLtvRow(String name, String count, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(count, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildInsightsTab(BuildContext context, SemanticColors colors, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historical Performance Insights',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _buildInsightListItem('Amendment rate is down to 4.2% (very high accuracy)'),
            _buildInsightListItem('Avg customer rating is 4.8/5.0 stars (Excellent satisfaction)'),
            _buildInsightListItem('Quotes per month has increased by 18% since automation was enabled'),
            _buildInsightListItem('Drywall bundles are accepted 78% of the time, painting is the lead driver'),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightListItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildInsightRow(
    BuildContext context, {
    required String title,
    required String desc,
    required String priority,
    required Color priorityColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: priorityColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            priority,
            style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
