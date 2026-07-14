import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';
import '../../components/mesh_background.dart';
import '../../components/glass_card.dart';
import '../../models/models.dart';


class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;

    final totalRevenue = ref.watch(totalRevenueProvider);
    final outstandingRevenue = ref.watch(outstandingRevenueProvider);
    final overdueInvoicesCount = ref.watch(overdueInvoicesCountProvider);
    final pendingQuotationsCount = ref.watch(pendingQuotationsCountProvider);
    final acceptedQuotationsCount = ref.watch(acceptedQuotationsCountProvider);
    final recentQuotations = ref.watch(quotationsProvider).take(3).toList();
    final recentInvoices = ref.watch(invoicesProvider).take(3).toList();

    final allInvoices = ref.watch(invoicesProvider);
    final paidCount = allInvoices.where((i) => i.status == 'Paid').length;
    final unpaidCount = allInvoices.where((i) => i.status == 'Sent').length;
    final draftCount = allInvoices.where((i) => i.status == 'Draft').length;

    final scheduleAsync = ref.watch(scheduleStreamProvider);
    final events = scheduleAsync.value ?? const [];

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(quotationsStreamProvider);
              ref.invalidate(invoicesStreamProvider);
            },
            child: CustomScrollView(
              slivers: [
                // ── App Bar ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(LucideIcons.menu),
                            onPressed: () => openDrawer(ref),
                          ),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Quote On The Go',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final unread =
                                ref.watch(unreadClientActivityCountProvider);
                            return SizedBox(
                              width: 40,
                              height: 40,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: 'Client Responses',
                                icon: Badge(
                                  isLabelVisible: unread > 0,
                                  label: Text(
                                      unread > 99 ? '99+' : unread.toString()),
                                  child: const Icon(LucideIcons.messageSquare),
                                ),
                                onPressed: () =>
                                    context.push('/client-responses'),
                              ),
                            );
                          },
                        ),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(LucideIcons.bell),
                            onPressed: () => context.push('/notifications'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── Global Search ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _GlobalSearchBar(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Smart Insights Card ──────────────────────────────────
                SliverToBoxAdapter(
                  child: _InsightsCard(
                    totalRevenue: totalRevenue,
                    outstandingRevenue: outstandingRevenue,
                    overdueCount: overdueInvoicesCount,
                    pendingQuotesCount: pendingQuotationsCount,
                    acceptedQuotesCount: acceptedQuotationsCount,
                    events: events,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── Stat Summary Card ────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _StatSummaryCard(
                      totalRevenue: totalRevenue,
                      outstandingRevenue: outstandingRevenue,
                      paidCount: paidCount,
                      unpaidCount: unpaidCount,
                      overdueCount: overdueInvoicesCount,
                      draftCount: draftCount,
                      onTap: () => context.push('/invoices'),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── Quick KPI chips ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _KpiChip(
                            label: 'Pending Quotes',
                            value: pendingQuotationsCount.toString(),
                            onTap: () => context.push('/quotations'),
                            isOrange: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiChip(
                            label: 'Accepted Quotes',
                            value: acceptedQuotationsCount.toString(),
                            onTap: () => context.push('/quotations?tab=accepted'),
                            isOrange: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Action Centre ─────────────────────────────────────────
                const SliverToBoxAdapter(
                  child: _ActionCentreSection(),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Today's Agenda ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: _TodayAgendaSection(events: events),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Charts ───────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MonthlyRevenueChart(
                      invoices: ref.watch(invoicesProvider),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _QuoteActivityChart(
                      quotations: ref.watch(quotationsProvider),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 28)),

                // ── Recent Invoices section ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionHeader(
                      title: 'Recent Invoices',
                      actionLabel: 'See All',
                      onAction: () => context.push('/invoices'),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                if (recentInvoices.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildEmptyCard('No invoices yet'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final inv = recentInvoices[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: _InvoiceCardRow(
                            invoice: inv,
                            semanticColors: semanticColors,
                            onTap: () => context.push('/invoices/${inv.id}'),
                          ),
                        );
                      },
                      childCount: recentInvoices.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Recent Quotations section ────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionHeader(
                      title: 'Recent Quotations',
                      actionLabel: 'See All',
                      onAction: () => context.push('/quotations'),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                if (recentQuotations.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildEmptyCard('No quotations yet'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final q = recentQuotations[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: _QuoteCardRow(
                            quotation: q,
                            semanticColors: semanticColors,
                            onTap: () => context.push('/quotations/${q.id}'),
                          ),
                        );
                      },
                      childCount: recentQuotations.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Status Overview ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionHeader(title: 'Status Overview'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _StatusOverviewCard(semanticColors: semanticColors),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── CTA Card ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _FeaturedCtaCard(
                      title: 'Create a New Quotation',
                      subtitle: 'Generate a professional quote for your next job in seconds.',
                      onTap: () => context.push('/quotations/new'),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Global Search Bar
// ─────────────────────────────────────────────────────────────────────────────
class _GlobalSearchBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GlobalSearchBar> createState() => _GlobalSearchBarState();
}

class _GlobalSearchBarState extends ConsumerState<_GlobalSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'quotation':
        return LucideIcons.fileText;
      case 'invoice':
        return LucideIcons.receipt;
      case 'customer':
        return LucideIcons.user;
      case 'job':
        return LucideIcons.calendar;
      default:
        return LucideIcons.search;
    }
  }

  Color _colorForType(String type, ColorScheme colorScheme) {
    switch (type) {
      case 'quotation':
        return const Color(0xFFF4781F);
      case 'invoice':
        return Colors.green;
      case 'customer':
        return Colors.blue;
      case 'job':
        return Colors.purple;
      default:
        return colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final query = ref.watch(dashboardSearchProvider);
    final results = ref.watch(searchResultsProvider);

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isFocused
                  ? const Color(0xFFF4781F)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: (value) =>
                ref.read(dashboardSearchProvider.notifier).state = value,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Search quotes, invoices, customers, jobs...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              prefixIcon: Icon(
                LucideIcons.search,
                size: 20,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        LucideIcons.x,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      onPressed: () {
                        _controller.clear();
                        ref.read(dashboardSearchProvider.notifier).state = '';
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (query.isNotEmpty && results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No results found for "$query"',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ),
          )
        else if (query.isNotEmpty && results.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: results.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, index) {
                final r = results[index];
                final iconColor = _colorForType(r.type, colorScheme);
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_iconForType(r.type), color: iconColor, size: 18),
                  ),
                  title: Text(
                    r.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    r.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  trailing: Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: isDark ? Colors.white24 : Colors.black54,
                  ),
                  onTap: () {
                    _controller.clear();
                    ref.read(dashboardSearchProvider.notifier).state = '';
                    context.push(r.route);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smart Insights Card (Deterministic & Local, Borderless Gemini Aesthetic)
// ─────────────────────────────────────────────────────────────────────────────
class _InsightsCard extends StatefulWidget {
  final double totalRevenue;
  final double outstandingRevenue;
  final int overdueCount;
  final int pendingQuotesCount;
  final int acceptedQuotesCount;
  final List<CalendarEvent> events;

  const _InsightsCard({
    required this.totalRevenue,
    required this.outstandingRevenue,
    required this.overdueCount,
    required this.pendingQuotesCount,
    required this.acceptedQuotesCount,
    required this.events,
  });

  @override
  State<_InsightsCard> createState() => _InsightsCardState();
}

class _InsightsCardState extends State<_InsightsCard> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Timer? _timer;
  late List<String> _insights;
  late AnimationController _auraController;

  @override
  void initState() {
    super.initState();
    _insights = _generateInsights();
    _startTimer();
    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void didUpdateWidget(_InsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newInsights = _generateInsights();
    if (newInsights.length != _insights.length || newInsights.first != _insights.first) {
      setState(() {
        _insights = newInsights;
        _currentIndex = 0;
      });
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_insights.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % _insights.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _auraController.dispose();
    super.dispose();
  }

  List<String> _generateInsights() {
    final list = <String>[];
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    // Job/Schedule Insights (Deterministic)
    final today = DateTime.now();
    final todayJobs = widget.events.where((e) {
      final startDt = DateTime.tryParse(e.start);
      if (startDt == null) return false;
      return startDt.year == today.year &&
             startDt.month == today.month &&
             startDt.day == today.day;
    }).toList();

    if (todayJobs.isNotEmpty) {
      list.add('You have ${todayJobs.length} job${todayJobs.length > 1 ? 's' : ''} scheduled for today. Tap to view your schedule.');
    }

    final activeJobs = widget.events.where((e) => e.status == 'In Progress' || e.status == 'En Route').toList();
    if (activeJobs.isNotEmpty) {
      list.add('You have ${activeJobs.length} job${activeJobs.length > 1 ? 's' : ''} currently in progress.');
    }

    // Invoice & Quote Insights
    if (widget.overdueCount > 0) {
      list.add('You have ${widget.overdueCount} overdue invoice${widget.overdueCount > 1 ? 's' : ''}. Tap to view and send reminders.');
    }
    if (widget.pendingQuotesCount > 0) {
      list.add('${widget.pendingQuotesCount} quotation${widget.pendingQuotesCount > 1 ? 's are' : ' is'} awaiting customer review. Follow up to speed up work.');
    }
    if (widget.outstandingRevenue > 0) {
      list.add('Outstanding revenue is ${fmt.format(widget.outstandingRevenue)}. Track your active invoices to speed up collections.');
    }
    if (widget.acceptedQuotesCount > 0) {
      list.add('Great news! ${widget.acceptedQuotesCount} quotation${widget.acceptedQuotesCount > 1 ? 's have' : ' has'} been accepted. Convert them to invoices.');
    }

    // Next upcoming job if no jobs today
    if (todayJobs.isEmpty) {
      final now = DateTime.now();
      final upcomingJobs = widget.events.where((e) {
        final startDt = DateTime.tryParse(e.start);
        if (startDt == null) return false;
        return startDt.isAfter(now);
      }).toList();

      if (upcomingJobs.isNotEmpty) {
        final nextJob = upcomingJobs.first;
        final startDt = DateTime.tryParse(nextJob.start);
        if (startDt != null) {
          final dateFmt = DateFormat('E d MMM').format(startDt);
          final timeFmt = DateFormat('jm').format(startDt);
          list.add('Next job: "${nextJob.title}" is scheduled for $dateFmt at $timeFmt.');
        }
      }
    }

    // Default catch-up messages
    if (list.isEmpty) {
      list.add('All caught up! Your business performance is healthy with ${fmt.format(widget.totalRevenue)} collected.');
      list.add('Tip: Create detailed quotes with custom items to win new jobs faster.');
    } else {
      list.add('Great progress! You have collected a total of ${fmt.format(widget.totalRevenue)} revenue.');
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_insights.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.8),
      height: 1.4,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        borderRadius: BorderRadius.circular(24),
        padding: EdgeInsets.zero, // Zero padding so gradient stripe sits flush against left edge
        onTap: () {
          final activeInsight = _insights[_currentIndex];
          if (activeInsight.contains('job') || activeInsight.contains('schedule') || activeInsight.contains('scheduled') || activeInsight.contains('progress')) {
            context.push('/schedule');
          } else if (activeInsight.contains('overdue')) {
            context.push('/invoices?tab=overdue');
          } else if (activeInsight.contains('quotation') || activeInsight.contains('review')) {
            context.push('/quotations');
          } else if (activeInsight.contains('revenue') || activeInsight.contains('outstanding')) {
            context.push('/invoices');
          } else {
            context.push('/quotations/new');
          }
        },
        child: AnimatedBuilder(
          animation: _auraController,
          builder: (context, child) {
            final double angle = _auraController.value * 2 * math.pi;
            final begin = Alignment(math.cos(angle), math.sin(angle));
            final end = Alignment(-math.cos(angle), -math.sin(angle));

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4285F4).withValues(alpha: isDark ? 0.08 : 0.05), // Gemini Blue
                    const Color(0xFF9B72CB).withValues(alpha: isDark ? 0.08 : 0.05), // Gemini Purple
                    const Color(0xFFF4781F).withValues(alpha: isDark ? 0.08 : 0.05), // Brand Orange
                  ],
                  begin: begin,
                  end: end,
                ),
              ),
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(_currentIndex),
                      child: Text(
                        _insights[_currentIndex],
                        style: textStyle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Summary Card (Frosted Glassmorphism, Adaptive)
// ─────────────────────────────────────────────────────────────────────────────
class _StatSummaryCard extends StatelessWidget {
  final double totalRevenue;
  final double outstandingRevenue;
  final int paidCount;
  final int unpaidCount;
  final int overdueCount;
  final int draftCount;
  final VoidCallback onTap;

  const _StatSummaryCard({
    required this.totalRevenue,
    required this.outstandingRevenue,
    required this.paidCount,
    required this.unpaidCount,
    required this.overdueCount,
    required this.draftCount,
    required this.onTap,
  });

  String _fmt(double v) => NumberFormat.currency(symbol: '£', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtleText = isDark ? Colors.white38 : Colors.black38;
    final bodyText = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fmt(totalRevenue),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total collected',
                    style: TextStyle(fontSize: 12, color: subtleText, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmt(outstandingRevenue),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF4781F),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Outstanding',
                    style: TextStyle(fontSize: 11, color: subtleText, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 16),

          Row(
            children: [
              _StatCell(value: paidCount.toString(), label: 'Paid', valueColor: isDark ? Colors.white : Colors.black87, labelColor: bodyText),
              _StatDivider(color: borderColor),
              _StatCell(value: unpaidCount.toString(), label: 'Unpaid', valueColor: isDark ? Colors.white : Colors.black87, labelColor: bodyText),
              _StatDivider(color: borderColor),
              _StatCell(value: overdueCount.toString(), label: 'Overdue', valueColor: const Color(0xFFFF3B30), labelColor: bodyText),
              _StatDivider(color: borderColor),
              _StatCell(value: draftCount.toString(), label: 'Draft', valueColor: isDark ? Colors.white : Colors.black87, labelColor: bodyText),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final Color labelColor;

  const _StatCell({required this.value, required this.label, required this.valueColor, required this.labelColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: labelColor),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final Color color;
  const _StatDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: color);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// High-Priority Action Centre (Dynamic reminders & quick actions)
// ─────────────────────────────────────────────────────────────────────────────
class _ActionCentreSection extends ConsumerWidget {
  const _ActionCentreSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final invoices = ref.watch(invoicesProvider);
    final quotations = ref.watch(quotationsProvider);

    // Build lists of actions
    final List<_DashboardActionItem> actionItems = [];

    // 1. Overdue Invoices
    final overdueInvoices = invoices.where((i) => i.status == 'Overdue').toList();
    for (final inv in overdueInvoices) {
      actionItems.add(_DashboardActionItem(
        title: 'Invoice #${inv.invoiceNumber} Overdue',
        subtitle: '${inv.customerName} · £${NumberFormat.decimalPattern().format(inv.total)}',
        actionLabel: 'Remind',
        icon: LucideIcons.triangleAlert,
        themeColor: semanticColors.error,
        onTap: () => context.push('/invoices/${inv.id}'),
        date: DateTime.tryParse(inv.dueDate),
      ));
    }

    // 2. Accepted Quotes (Prompt to Bill/Convert to Invoice)
    final acceptedQuotes = quotations.where((q) => q.status == 'Accepted').toList();
    for (final q in acceptedQuotes) {
      actionItems.add(_DashboardActionItem(
        title: 'Bill Accepted Quote #${q.quotationNumber}',
        subtitle: '${q.customerName} · £${NumberFormat.decimalPattern().format(q.total)}',
        actionLabel: 'Bill',
        icon: LucideIcons.checkCircle2,
        themeColor: semanticColors.success,
        onTap: () => context.push('/quotations/${q.id}'),
        date: DateTime.tryParse(q.date),
      ));
    }

    // 3. Draft Invoices (Prompt to Send)
    final draftInvoices = invoices.where((i) => i.status == 'Draft').toList();
    for (final inv in draftInvoices) {
      actionItems.add(_DashboardActionItem(
        title: 'Send Draft Invoice #${inv.invoiceNumber}',
        subtitle: '${inv.customerName} · £${NumberFormat.decimalPattern().format(inv.total)}',
        actionLabel: 'Send',
        icon: LucideIcons.send,
        themeColor: const Color(0xFFF4781F), // Brand Orange
        onTap: () => context.push('/invoices/${inv.id}'),
        date: DateTime.tryParse(inv.createdAt?.toIso8601String() ?? ''),
      ));
    }

    // Take top 3 highest priority items to avoid cluttering the dashboard
    final visibleItems = actionItems.take(3).toList();

    if (visibleItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Action Centre'),
            const SizedBox(height: 12),
            GlassCard(
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: semanticColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.sparkles,
                      color: semanticColors.success,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'All caught up',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No high-priority business tasks require your attention.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SectionHeader(
            title: 'Action Centre',
            actionLabel: actionItems.length > 3 ? 'View All (${actionItems.length})' : null,
            onAction: actionItems.length > 3 ? () => context.push('/invoices') : null,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleItems.length,
          itemBuilder: (context, index) {
            final item = visibleItems[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: _ActionItemCard(item: item),
            );
          },
        ),
      ],
    );
  }
}

class _DashboardActionItem {
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData icon;
  final Color themeColor;
  final VoidCallback onTap;
  final DateTime? date;

  _DashboardActionItem({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.icon,
    required this.themeColor,
    required this.onTap,
    this.date,
  });
}

class _ActionItemCard extends StatelessWidget {
  final _DashboardActionItem item;

  const _ActionItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(12),
      onTap: item.onTap,
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              color: item.themeColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Action Button
          TextButton(
            onPressed: item.onTap,
            style: TextButton.styleFrom(
              backgroundColor: item.themeColor.withValues(alpha: 0.12),
              foregroundColor: item.themeColor,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              item.actionLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's Agenda Preview (Deterministic Jobs & Status Triggers)
// ─────────────────────────────────────────────────────────────────────────────
class _TodayAgendaSection extends ConsumerWidget {
  final List<CalendarEvent> events;

  const _TodayAgendaSection({required this.events});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter today's events
    final today = DateTime.now();
    final todayEvents = events.where((e) {
      final startDt = DateTime.tryParse(e.start);
      if (startDt == null) return false;
      return startDt.year == today.year &&
             startDt.month == today.month &&
             startDt.day == today.day;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SectionHeader(
            title: "Today's Agenda",
            actionLabel: "View Calendar",
            onAction: () => context.push('/schedule'),
          ),
        ),
        const SizedBox(height: 12),
        if (todayEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.calendarDays,
                      size: 28,
                      color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No jobs scheduled for today',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todayEvents.length,
            itemBuilder: (context, index) {
              final event = todayEvents[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: _AgendaJobCard(
                  event: event,
                  semanticColors: semanticColors,
                  onStatusUpdate: (newStatus) async {
                    final updatedEvent = event.copyWith(
                      status: newStatus,
                      enRouteAt: newStatus == 'En Route' ? DateTime.now().toIso8601String() : event.enRouteAt,
                      startedAt: newStatus == 'In Progress' ? DateTime.now().toIso8601String() : event.startedAt,
                      completedAt: newStatus == 'Completed' ? DateTime.now().toIso8601String() : event.completedAt,
                    );
                    await ref.read(scheduleRepositoryProvider).updateEvent(updatedEvent);
                    ref.invalidate(scheduleStreamProvider);
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

class _AgendaJobCard extends StatelessWidget {
  final CalendarEvent event;
  final SemanticColors semanticColors;
  final ValueChanged<String> onStatusUpdate;

  const _AgendaJobCard({
    required this.event,
    required this.semanticColors,
    required this.onStatusUpdate,
  });

  String _formatTime(String isoString) {
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '';
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = _formatTime(event.start);
    final status = event.status ?? 'Pending';

    Widget actionButton;
    if (status == 'Completed') {
      actionButton = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.checkCircle2, color: semanticColors.success, size: 16),
          const SizedBox(width: 4),
          Text(
            'Done',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: semanticColors.success,
            ),
          ),
        ],
      );
    } else {
      String btnLabel = 'En Route';
      String nextStatus = 'En Route';
      Color btnColor = const Color(0xFFF4781F); // Orange for travel
      
      if (status == 'En Route') {
        btnLabel = 'Start';
        nextStatus = 'In Progress';
        btnColor = const Color(0xFF4285F4); // Blue for start
      } else if (status == 'In Progress') {
        btnLabel = 'Complete';
        nextStatus = 'Completed';
        btnColor = const Color(0xFF34A853); // Green for complete
      }

      actionButton = TextButton(
        onPressed: () => onStatusUpdate(nextStatus),
        style: TextButton.styleFrom(
          backgroundColor: btnColor.withValues(alpha: 0.12),
          foregroundColor: btnColor,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          btnLabel,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
    }

    return GlassCard(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Time Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                event.status ?? 'Scheduled',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: status == 'In Progress'
                      ? const Color(0xFF4285F4)
                      : (status == 'Completed' ? semanticColors.success : (isDark ? Colors.white38 : Colors.black38)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Divider
          Container(
            width: 1,
            height: 36,
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
          const SizedBox(width: 16),
          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.customerName != null && event.customerName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.customerName!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Quick Action Trigger
          actionButton,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly Revenue Bar Chart  (last 6 months of paid invoices)
// ─────────────────────────────────────────────────────────────────────────────
class _MonthlyRevenueChart extends StatelessWidget {
  final List<Invoice> invoices;

  const _MonthlyRevenueChart({required this.invoices});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtleText = isDark ? Colors.white38 : Colors.black38;
    final now = DateTime.now();

    // Build last-6-months buckets
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - 5 + i, 1);
      return d;
    });

    final data = months.map((m) {
      final total = invoices
          .where((inv) =>
              inv.status == 'Paid' &&
              inv.createdAt != null &&
              inv.createdAt!.year == m.year &&
              inv.createdAt!.month == m.month)
          .fold(0.0, (acc, inv) => acc + inv.total);
      return total;
    }).toList();

    final maxY = data.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxY < 1 ? 1000.0 : maxY * 1.25;

    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Revenue',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last 6 months · paid invoices',
            style: TextStyle(fontSize: 11, color: subtleText, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: effectiveMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: effectiveMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('MMM').format(months[idx]),
                            style: TextStyle(fontSize: 10, color: subtleText, fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(6, (i) {
                  final isLast = i == 5;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: data[i],
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        gradient: isLast
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFF4781F), // Brand Orange
                                  Color(0xFFFF9E59), // Soft Coral
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )
                            : null,
                        color: isLast
                            ? null
                            : (isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08)),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        NumberFormat.currency(symbol: '£', decimalDigits: 0).format(rod.toY),
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quote Activity Line Chart  (sent vs accepted, last 6 months)
// ─────────────────────────────────────────────────────────────────────────────
class _QuoteActivityChart extends StatelessWidget {
  final List<Quotation> quotations;

  const _QuoteActivityChart({required this.quotations});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtleText = isDark ? Colors.white38 : Colors.black38;
    final now = DateTime.now();

    final months = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i, 1));

    List<FlSpot> buildSpots(String status) {
      return List.generate(6, (i) {
        final m = months[i];
        final count = quotations
            .where((q) =>
                q.status == status &&
                q.createdAt != null &&
                q.createdAt!.year == m.year &&
                q.createdAt!.month == m.month)
            .length
            .toDouble();
        return FlSpot(i.toDouble(), count);
      });
    }

    final sentSpots = buildSpots('Sent');
    final acceptedSpots = buildSpots('Accepted');
    final allY = [...sentSpots, ...acceptedSpots].map((s) => s.y).toList();
    final maxY = allY.isEmpty ? 1.0 : allY.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxY < 1 ? 4.0 : maxY * 1.4;

    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quote Activity',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last 6 months',
                    style: TextStyle(fontSize: 11, color: subtleText, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Spacer(),
              // Legend
              Row(
                children: [
                  _ChartLegendDot(color: isDark ? Colors.white.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.14)),
                  const SizedBox(width: 4),
                  Text('Sent', style: TextStyle(fontSize: 10, color: subtleText, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  const _ChartLegendDot(color: Color(0xFFF4781F)),
                  const SizedBox(width: 4),
                  Text('Accepted', style: TextStyle(fontSize: 10, color: subtleText, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                maxY: effectiveMax,
                minY: 0,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: effectiveMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('MMM').format(months[idx]),
                            style: TextStyle(fontSize: 10, color: subtleText, fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: sentSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: isDark ? Colors.white.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.14),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: acceptedSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFF4781F),
                        Color(0xFFFF8A47),
                      ],
                    ),
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: const Color(0xFFF4781F),
                        strokeWidth: 1.2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF4781F).withValues(alpha: 0.12),
                          const Color(0xFFF4781F).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    getTooltipItems: (spots) => spots.map((s) {
                      return LineTooltipItem(
                        s.y.toInt().toString(),
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: s.bar.color ?? s.bar.gradient?.colors.first ?? Colors.orange,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  const _ChartLegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Chip (compact split cards)
// ─────────────────────────────────────────────────────────────────────────────
class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isOrange;

  const _KpiChip({
    required this.label,
    required this.value,
    required this.onTap,
    required this.isOrange,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isOrange) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFF4781F), // Brand Orange
              Color(0xFFFF8C42), // Coral Glow
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF4781F).withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return GlassCard(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF4781F),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: Color(0xFFF4781F),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoice Card Row  (rich: avatar initials + name/email + badge + amount/no/date)
// ─────────────────────────────────────────────────────────────────────────────
class _InvoiceCardRow extends StatelessWidget {
  final Invoice invoice;
  final SemanticColors semanticColors;
  final VoidCallback onTap;

  const _InvoiceCardRow({
    required this.invoice,
    required this.semanticColors,
    required this.onTap,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return semanticColors.success;
      case 'Sent':
        return semanticColors.info;
      case 'Overdue':
        return semanticColors.error;
      case 'Draft':
        return semanticColors.warning;
      default:
        return semanticColors.accentBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(invoice.status);
    final dateStr = invoice.dueDate.isNotEmpty
        ? DateFormat('d MMM yyyy').format(DateTime.tryParse(invoice.dueDate) ?? DateTime.now())
        : '—';

    return GlassCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name/email + status badge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.customerName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.customerEmail,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(label: invoice.status, color: statusColor),
            ],
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
          const SizedBox(height: 12),

          // Bottom row: amount + number + date
          Row(
            children: [
              _MetaCell(
                label: 'Amount',
                value: NumberFormat.currency(symbol: '£', decimalDigits: 0).format(invoice.total),
                valueStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              _MetaCell(
                label: 'No.',
                value: '#${invoice.invoiceNumber}',
                valueStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              _MetaCell(
                label: 'Due',
                value: dateStr,
                valueStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                isLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quote Card Row  (rich: avatar initials + name + badge + amount/no/date)
// ─────────────────────────────────────────────────────────────────────────────
class _QuoteCardRow extends StatelessWidget {
  final Quotation quotation;
  final SemanticColors semanticColors;
  final VoidCallback onTap;

  const _QuoteCardRow({
    required this.quotation,
    required this.semanticColors,
    required this.onTap,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'Accepted':
        return semanticColors.success;
      case 'Sent':
        return semanticColors.info;
      case 'Declined':
        return semanticColors.error;
      case 'Draft':
        return semanticColors.warning;
      default:
        return semanticColors.accentPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(quotation.status);
    final dateStr = quotation.date.isNotEmpty
        ? DateFormat('d MMM yyyy').format(DateTime.tryParse(quotation.date) ?? DateTime.now())
        : '—';

    return GlassCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name/email + status badge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quotation.customerName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quotation.customerEmail,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(label: quotation.status, color: statusColor),
            ],
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
          const SizedBox(height: 12),

          // Bottom row: amount + number + date
          Row(
            children: [
              _MetaCell(
                label: 'Amount',
                value: NumberFormat.currency(symbol: '£', decimalDigits: 0).format(quotation.total),
                valueStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              _MetaCell(
                label: 'No.',
                value: '#${quotation.quotationNumber}',
                valueStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              _MetaCell(
                label: 'Date',
                value: dateStr,
                valueStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                isLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle valueStyle;
  final bool isLast;

  const _MetaCell({
    required this.label,
    required this.value,
    required this.valueStyle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        crossAxisAlignment: isLast ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Overview Card
// ─────────────────────────────────────────────────────────────────────────────
class _StatusOverviewCard extends ConsumerWidget {
  final SemanticColors semanticColors;

  const _StatusOverviewCard({required this.semanticColors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdueInvoicesCount = ref.watch(overdueInvoicesCountProvider);
    final acceptedQuotationsCount = ref.watch(acceptedQuotationsCountProvider);
    final pendingQuotationsCount = ref.watch(pendingQuotationsCountProvider);

    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _StatusListRow(
            label: 'Overdue Invoices',
            value: overdueInvoicesCount.toString(),
            color: semanticColors.error,
            icon: LucideIcons.triangleAlert,
            showDivider: true,
            onTap: () => GoRouter.of(context).push('/invoices?tab=overdue'),
          ),
          _StatusListRow(
            label: 'Accepted Quotes',
            value: acceptedQuotationsCount.toString(),
            color: semanticColors.success,
            icon: LucideIcons.checkCircle,
            showDivider: true,
            onTap: () => GoRouter.of(context).push('/quotations?tab=accepted'),
          ),
          _StatusListRow(
            label: 'Pending Quotes',
            value: pendingQuotationsCount.toString(),
            color: semanticColors.warning,
            icon: LucideIcons.clock,
            showDivider: false,
            onTap: () => GoRouter.of(context).push('/quotations?tab=sent'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status List Row
// ─────────────────────────────────────────────────────────────────────────────
class _StatusListRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool showDivider;
  final VoidCallback? onTap;

  const _StatusListRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.showDivider,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 66,
            endIndent: 16,
            color: isDark ? Colors.white10 : Colors.black12,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured CTA Card
// ─────────────────────────────────────────────────────────────────────────────
class _FeaturedCtaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeaturedCtaCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF4781F).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: GlassCard(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF4781F).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                LucideIcons.plusCircle,
                color: Color(0xFFF4781F),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF4781F),
                    Color(0xFFFF6B4A),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF4781F).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(100),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(
                      'New Quote',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
