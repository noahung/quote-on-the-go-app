import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../components/glass_card.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../theme/design_tokens.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _searchOpen = false;
  late final Timer _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quotes = ref.watch(quotationsStreamProvider);
    final invoices = ref.watch(invoicesStreamProvider);
    final schedule = ref.watch(scheduleStreamProvider);
    return DashboardContent(
      name: ref.watch(userProfileProvider)?.displayName ?? '',
      quotations: quotes.valueOrNull ?? const [],
      invoices: invoices.valueOrNull ?? const [],
      events: schedule.valueOrNull ?? const [],
      now: DateTime.now(),
      loading: (quotes.isLoading && !quotes.hasValue) ||
          (invoices.isLoading && !invoices.hasValue),
      failed: quotes.hasError || invoices.hasError,
      scheduleLoading: schedule.isLoading && !schedule.hasValue,
      scheduleFailed: schedule.hasError,
      unreadResponses: ref.watch(unreadClientActivityCountProvider),
      onNavigate: (route) => context.push(route),
      onMenu: () => openDrawer(ref),
      onSearch: () => setState(() => _searchOpen = !_searchOpen),
      search: _searchOpen ? const _HomeSearch() : null,
      onRefresh: () async {
        ref.invalidate(quotationsStreamProvider);
        ref.invalidate(invoicesStreamProvider);
        ref.invalidate(scheduleStreamProvider);
        // Wait for the refreshed streams, keeping errors in their inline states.
        await Future.wait([
          ref
              .read(quotationsStreamProvider.future)
              .then<void>((_) {}, onError: (Object _, StackTrace __) {}),
          ref
              .read(invoicesStreamProvider.future)
              .then<void>((_) {}, onError: (Object _, StackTrace __) {}),
          ref
              .read(scheduleStreamProvider.future)
              .then<void>((_) {}, onError: (Object _, StackTrace __) {}),
        ]);
      },
    );
  }
}

/// Presentation stays independent of Firebase so real layouts and states are testable.
class DashboardContent extends StatefulWidget {
  final String name;
  final List<Quotation> quotations;
  final List<Invoice> invoices;
  final List<CalendarEvent> events;
  final DateTime now;
  final bool loading, failed, scheduleLoading, scheduleFailed;
  final int unreadResponses;
  final void Function(String) onNavigate;
  final VoidCallback onMenu, onSearch;
  final Future<void> Function() onRefresh;
  final Widget? search;
  const DashboardContent(
      {super.key,
      required this.name,
      required this.quotations,
      required this.invoices,
      required this.events,
      required this.now,
      required this.onNavigate,
      required this.onMenu,
      required this.onSearch,
      required this.onRefresh,
      this.loading = false,
      this.failed = false,
      this.scheduleLoading = false,
      this.scheduleFailed = false,
      this.unreadResponses = 0,
      this.search});
  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  bool _showAllAttention = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final firstName = widget.name.trim().split(RegExp(r'\s+')).first;
    final quotes = widget.quotations.where((q) => !q.isArchived).toList();
    final invoices = widget.invoices.where((i) => !i.isArchived).toList();
    final outstanding = invoices
        .where((i) => i.status == 'Sent' || i.status == 'Overdue')
        .fold(0.0, (sum, i) => sum + i.total);
    final drafts = quotes.where((q) => q.status == 'Draft').length;
    final awaiting = quotes.where((q) => q.status == 'Sent').length;
    final attention = homeAttentionItems(quotes, widget.invoices, widget.now);
    final today = DateUtils.dateOnly(widget.now);
    final tomorrow = today.add(const Duration(days: 1));
    final jobs = widget.events.where((event) {
      final start = DateTime.tryParse(event.start)?.toLocal();
      final end = DateTime.tryParse(event.end)?.toLocal();
      return start != null &&
          start.isBefore(tomorrow) &&
          ((end != null && end.isAfter(today)) || !start.isBefore(today)) &&
          event.status?.toLowerCase() != 'cancelled';
    }).toList()
      ..sort(
          (a, b) => DateTime.parse(a.start).compareTo(DateTime.parse(b.start)));
    final money = NumberFormat.currency(locale: 'en_GB', symbol: '£');
    void go(String route) => widget.onNavigate(route);
    Widget heading(String label) => Padding(
        padding: const EdgeInsets.only(top: 32, bottom: 14),
        child: Semantics(
            header: true, child: Text(label, style: text.titleLarge)));
    return SafeArea(
        child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: DesignTokens.contentWidth),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: DesignTokens.pagePadding),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                        padding: const EdgeInsets.only(
                                            top: 8, bottom: 24),
                                        child: Row(children: [
                                          IconButton(
                                              tooltip: 'Open menu',
                                              onPressed: widget.onMenu,
                                              icon:
                                                  const Icon(LucideIcons.menu)),
                                          const Spacer(),
                                          IconButton(
                                              tooltip: widget.search == null
                                                  ? 'Search your business'
                                                  : 'Close search',
                                              onPressed: widget.onSearch,
                                              icon: Icon(widget.search == null
                                                  ? LucideIcons.search
                                                  : LucideIcons.x)),
                                          IconButton(
                                              tooltip: 'Notifications',
                                              onPressed: () =>
                                                  go('/notifications'),
                                              icon:
                                                  const Icon(LucideIcons.bell)),
                                          IconButton(
                                              tooltip: 'Your profile',
                                              onPressed: () => go('/profile'),
                                              icon: const Icon(
                                                  LucideIcons.userRound)),
                                        ])),
                                    if (widget.search != null) ...[
                                      widget.search!,
                                      const SizedBox(height: 24)
                                    ],
                                    Semantics(
                                        header: true,
                                        child: Text(
                                            firstName.isEmpty
                                                ? 'Hello there'
                                                : 'Hi $firstName',
                                            style: text.headlineLarge)),
                                    const SizedBox(height: 10),
                                    Text(
                                        DateFormat('EEEE, d MMMM')
                                            .format(widget.now),
                                        style: text.bodyLarge?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant)),
                                    heading('Your business'),
                                    if (widget.loading)
                                      const _LoadingPanel(
                                          label: 'Loading quotes and invoices')
                                    else if (widget.failed)
                                      _RetryPanel(
                                          message:
                                              'Your business summary could not load.',
                                          onRetry: widget.onRefresh)
                                    else
                                      GlassCard(
                                          padding: EdgeInsets.zero,
                                          child: Column(children: [
                                            HomeActionRow(
                                                icon: LucideIcons.fileText,
                                                title: 'Quotes',
                                                subtitle: quotes.isEmpty
                                                    ? 'Your next job starts here'
                                                    : '$drafts ${drafts == 1 ? 'draft' : 'drafts'} · $awaiting awaiting a reply',
                                                onTap: () => go('/quotations')),
                                            const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 20),
                                                child: Divider(height: 1)),
                                            HomeActionRow(
                                                icon: LucideIcons.receipt,
                                                title: 'Invoices',
                                                subtitle: invoices.isEmpty
                                                    ? 'Keep your payments in one place'
                                                    : '${money.format(outstanding)} outstanding',
                                                onTap: () => go('/invoices')),
                                          ])),
                                    const SizedBox(height: 20),
                                    FilledButton(
                                        onPressed: () => go('/quotations/new'),
                                        child: const Text('Create quote')),
                                    const SizedBox(height: 4),
                                    TextButton(
                                        onPressed: () => go('/invoices/new'),
                                        child: const Text('Create invoice')),
                                    if (!widget.loading &&
                                        !widget.failed &&
                                        attention.isNotEmpty) ...[
                                      heading('Needs attention'),
                                      for (final item in (_showAllAttention
                                          ? attention
                                          : attention.take(3)))
                                        HomeActionRow(
                                            icon: item.icon,
                                            title: item.title,
                                            subtitle: item.subtitle,
                                            onTap: () => go(item.route),
                                            horizontalPadding: 0),
                                      if (attention.length > 3)
                                        Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton(
                                                onPressed: () => setState(() =>
                                                    _showAllAttention =
                                                        !_showAllAttention),
                                                child: Text(_showAllAttention
                                                    ? 'Show fewer'
                                                    : 'Show all ${attention.length} tasks'))),
                                    ],
                                    heading('Today'),
                                    if (widget.scheduleLoading)
                                      const _LoadingPanel(
                                          label: 'Loading today’s schedule')
                                    else if (widget.scheduleFailed)
                                      _RetryPanel(
                                          message:
                                              'Today’s schedule could not load.',
                                          onRetry: widget.onRefresh)
                                    else if (jobs.isEmpty)
                                      GlassCard(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text('No jobs scheduled today',
                                                style: text.titleMedium),
                                            const SizedBox(height: 8),
                                            Text('Make room for your next job.',
                                                style: text.bodyLarge?.copyWith(
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant)),
                                            const SizedBox(height: 12),
                                            OutlinedButton(
                                                onPressed: () =>
                                                    go('/schedule/new'),
                                                child: const Text(
                                                    'Schedule a job')),
                                          ]))
                                    else
                                      GlassCard(
                                          padding: EdgeInsets.zero,
                                          child: Column(children: [
                                            for (final job in jobs.take(2))
                                              HomeActionRow(
                                                  icon: LucideIcons.calendar,
                                                  title: job.title.isEmpty
                                                      ? 'Scheduled job'
                                                      : job.title,
                                                  subtitle:
                                                      '${job.allDay == true ? 'All day' : DateFormat('HH:mm').format(DateTime.parse(job.start).toLocal())} · ${job.customerName?.isNotEmpty == true ? job.customerName : 'View job'}${job.status == null ? '' : ' · ${job.status}'}',
                                                  onTap: () => go(
                                                      '/schedule/${job.id}')),
                                          ])),
                                    Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton(
                                            onPressed: () => go('/schedule'),
                                            child: Text(jobs.length > 2
                                                ? 'View all ${jobs.length} jobs'
                                                : 'View schedule'))),
                                    heading('Keep things moving'),
                                    HomeActionRow(
                                        icon: LucideIcons.messageSquare,
                                        title: 'Client responses',
                                        subtitle: widget.unreadResponses > 0
                                            ? '${widget.unreadResponses} unread responses'
                                            : 'Messages and document activity',
                                        onTap: () => go('/client-responses'),
                                        horizontalPadding: 0),
                                    const Divider(height: 1),
                                    HomeActionRow(
                                        icon: LucideIcons.chartNoAxesCombined,
                                        title: 'Analytics',
                                        subtitle:
                                            'Revenue, quote trends and reports',
                                        onTap: () => go('/analytics'),
                                        horizontalPadding: 0),
                                  ]))))
                ])));
  }
}

class HomeAttentionItem {
  final IconData icon;
  final String title, subtitle, route;
  const HomeAttentionItem(this.icon, this.title, this.subtitle, this.route);
}

/// Uses due dates, excludes archived documents and quotes already converted.
List<HomeAttentionItem> homeAttentionItems(
    List<Quotation> quotes, List<Invoice> invoices, DateTime now) {
  final day = DateUtils.dateOnly(now);
  final overdue = invoices.where((i) {
    final due = DateTime.tryParse(i.dueDate);
    return !i.isArchived &&
        (i.status == 'Overdue' ||
            (i.status == 'Sent' &&
                due != null &&
                DateUtils.dateOnly(due).isBefore(day)));
  }).toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  final invoiced =
      invoices.map((i) => i.quotationId).whereType<String>().toSet();
  final result = <HomeAttentionItem>[
    for (final i in overdue)
      HomeAttentionItem(LucideIcons.clock, 'Payment overdue',
          '${i.customerName} · ${i.invoiceNumber}', '/invoices/${i.id}'),
    for (final q in quotes.where((q) =>
        !q.isArchived && q.status == 'Accepted' && !invoiced.contains(q.id)))
      HomeAttentionItem(LucideIcons.check, 'Quote accepted',
          '${q.customerName} · ${q.quotationNumber}', '/quotations/${q.id}'),
    for (final i in invoices
        .where((i) => !i.isArchived && i.approvalStatus == 'pending'))
      HomeAttentionItem(LucideIcons.clipboardCheck, 'Invoice awaiting approval',
          '${i.customerName} · ${i.invoiceNumber}', '/invoices/${i.id}'),
    for (final q
        in quotes.where((q) => !q.isArchived && q.approvalStatus == 'pending'))
      HomeAttentionItem(LucideIcons.clipboardCheck, 'Quote awaiting approval',
          '${q.customerName} · ${q.quotationNumber}', '/quotations/${q.id}'),
  ];
  return result;
}

/// One accessible tap target with a wrapping label and an explicit destination.
class HomeActionRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final double horizontalPadding;
  const HomeActionRow(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap,
      this.horizontalPadding = 20});
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: 20),
              child: Row(children: [
                Icon(icon, size: 26),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 5),
                      Text(subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ])),
                const SizedBox(width: 12),
                const Icon(LucideIcons.chevronRight, size: 20),
              ]))));
}

class _LoadingPanel extends StatelessWidget {
  final String label;
  const _LoadingPanel({required this.label});
  @override
  Widget build(BuildContext context) => GlassCard(
          child: Row(children: [
        const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 16),
        Expanded(child: Text(label)),
      ]));
}

class _RetryPanel extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _RetryPanel({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => GlassCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Try again'))
      ]));
}

class _HomeSearch extends ConsumerStatefulWidget {
  const _HomeSearch();
  @override
  ConsumerState<_HomeSearch> createState() => _HomeSearchState();
}

class _HomeSearchState extends ConsumerState<_HomeSearch> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: ref.read(dashboardSearchProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(dashboardSearchProvider);
    final results = ref.watch(searchResultsProvider);
    final states = [
      ref.watch(quotationsStreamProvider),
      ref.watch(invoicesStreamProvider),
      ref.watch(customersStreamProvider),
      ref.watch(scheduleStreamProvider)
    ];
    final loading = states.any((s) => s.isLoading);
    final failed = states.any((s) => s.hasError);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (value) =>
              ref.read(dashboardSearchProvider.notifier).state = value,
          decoration: InputDecoration(
              labelText: 'Search your business',
              hintText: 'Customer, document or job',
              prefixIcon: const Icon(LucideIcons.search),
              suffixIcon: IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _controller.clear();
                    ref.read(dashboardSearchProvider.notifier).state = '';
                  },
                  icon: const Icon(LucideIcons.x)))),
      if (query.trim().isNotEmpty) ...[
        if (loading)
          const Padding(padding: EdgeInsets.all(16), child: Text('Searching…')),
        if (failed)
          const Padding(
              padding: EdgeInsets.all(16),
              child:
                  Text('Some results could not load. Pull down to try again.')),
        if (!loading && !failed && results.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No matches. Try a name or document number.')),
        for (final result in results)
          ListTile(
              title: Text(result.title),
              subtitle: Text(result.subtitle),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => context.push(result.route)),
      ],
    ]);
  }
}
