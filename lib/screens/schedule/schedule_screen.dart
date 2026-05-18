import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_event.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<CalendarEvent> _eventsForDay(List<CalendarEvent> events, DateTime day) {
    return events.where((e) {
      final start = DateTime.tryParse(e.start);
      if (start == null) return false;
      return start.year == day.year &&
          start.month == day.month &&
          start.day == day.day;
    }).toList();
  }

  List<CalendarEvent> _todayEvents(List<CalendarEvent> events) {
    return _eventsForDay(events, _selectedDay)
      ..sort((a, b) {
        final da = DateTime.tryParse(a.start);
        final db = DateTime.tryParse(b.start);
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });
  }

  List<CalendarEvent> _upcomingEvents(List<CalendarEvent> events) {
    final now = DateTime.now();
    return events.where((e) {
      final start = DateTime.tryParse(e.start);
      return start != null && start.isAfter(now);
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a.start);
        final db = DateTime.tryParse(b.start);
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });
  }

  List<CalendarEvent> _pastEvents(List<CalendarEvent> events) {
    final now = DateTime.now();
    return events.where((e) {
      final end = DateTime.tryParse(e.end);
      return end != null && end.isBefore(now);
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a.start);
        final db = DateTime.tryParse(b.start);
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scheduleAsync = ref.watch(scheduleStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Go to today',
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _focusedMonth = DateTime(now.year, now.month);
                _selectedDay = DateTime(now.year, now.month, now.day);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/schedule/new'),
          ),
        ],
      ),
      body: scheduleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (events) {
          final today = _todayEvents(events);
          final upcoming = _upcomingEvents(events);
          final past = _pastEvents(events);

          return Column(
            children: [
              // ── Calendar ──────────────────────────────────────────────
              _CalendarSection(
                focusedMonth: _focusedMonth,
                selectedDay: _selectedDay,
                events: events,
                eventsForDay: _eventsForDay,
                onDaySelected: (day) => setState(() => _selectedDay = day),
                onPreviousMonth: () => setState(() {
                  _focusedMonth =
                      DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                }),
                onNextMonth: () => setState(() {
                  _focusedMonth =
                      DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                }),
              ),

              const Divider(height: 1),

              // ── Tabs ──────────────────────────────────────────────────
              TabBar(
                controller: _tabController,
                labelStyle: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Today'),
                        if (today.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _CountBadge(
                              count: today.length, color: colorScheme.primary),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Upcoming'),
                        if (upcoming.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _CountBadge(
                              count: upcoming.length,
                              color: colorScheme.primary),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Past'),
                ],
              ),

              // ── Tab content ───────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _EventList(
                      events: today,
                      emptyTitle:
                          'No events on ${DateFormat('MMM d').format(_selectedDay)}',
                      emptySubtitle: 'Tap + to schedule something.',
                      onAddTap: () => context.push('/schedule/new'),
                    ),
                    _EventList(
                      events: upcoming,
                      emptyTitle: 'No upcoming events',
                      emptySubtitle: 'Your future jobs will appear here.',
                      onAddTap: () => context.push('/schedule/new'),
                    ),
                    _EventList(
                      events: past,
                      emptyTitle: 'No past events',
                      emptySubtitle: 'Completed jobs will appear here.',
                      onAddTap: null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/schedule/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Calendar section ──────────────────────────────────────────────────────────

class _CalendarSection extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<CalendarEvent> events;
  final List<CalendarEvent> Function(List<CalendarEvent>, DateTime)
      eventsForDay;
  final void Function(DateTime) onDaySelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _CalendarSection({
    required this.focusedMonth,
    required this.selectedDay,
    required this.events,
    required this.eventsForDay,
    required this.onDaySelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Month navigator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPreviousMonth),
              Text(
                DateFormat('MMMM yyyy').format(focusedMonth),
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNextMonth),
            ],
          ),
        ),

        // Day-of-week labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            )),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),

        // Day grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _DayGrid(
            focusedMonth: focusedMonth,
            selectedDay: selectedDay,
            events: events,
            eventsForDay: eventsForDay,
            onDaySelected: onDaySelected,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _DayGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<CalendarEvent> events;
  final List<CalendarEvent> Function(List<CalendarEvent>, DateTime)
      eventsForDay;
  final void Function(DateTime) onDaySelected;

  const _DayGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.events,
    required this.eventsForDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now();

    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final startOffset = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth =
        DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
    final rows = ((startOffset + daysInMonth) / 7).ceil();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final dayNum = index - startOffset + 1;
        if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();

        final day = DateTime(focusedMonth.year, focusedMonth.month, dayNum);
        final isToday = day.year == today.year &&
            day.month == today.month &&
            day.day == today.day;
        final isSelected = day.year == selectedDay.year &&
            day.month == selectedDay.month &&
            day.day == selectedDay.day;
        final dayEvents = eventsForDay(events, day);

        // Collect up to 3 event dot colours
        final dotColors = dayEvents.take(3).map((e) {
          if (e.color == null) return colorScheme.primary;
          try {
            return Color(int.parse(e.color!.replaceFirst('#', '0xff')));
          } catch (_) {
            return colorScheme.primary;
          }
        }).toList();

        return GestureDetector(
          onTap: () => onDaySelected(day),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary
                  : isToday
                      ? colorScheme.primaryContainer
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$dayNum',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: isToday || isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : isToday
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                  ),
                ),
                if (dotColors.isNotEmpty)
                  Positioned(
                    bottom: 3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: dotColors
                          .map((c) => Container(
                                width: 4,
                                height: 4,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? colorScheme.onPrimary : c,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Event list ────────────────────────────────────────────────────────────────

class _EventList extends StatelessWidget {
  final List<CalendarEvent> events;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback? onAddTap;

  const _EventList({
    required this.events,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return AppEmptyState(
        icon: Icons.calendar_today_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionLabel: onAddTap != null ? 'Add Event' : null,
        onAction: onAddTap,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: events.length,
      itemBuilder: (context, i) => _EventTile(event: events[i]),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final start = DateTime.tryParse(event.start);
    final end = DateTime.tryParse(event.end);
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('EEE, MMM d');

    Color eventColor;
    try {
      eventColor = event.color != null
          ? Color(int.parse(event.color!.replaceFirst('#', '0xff')))
          : colorScheme.primary;
    } catch (_) {
      eventColor = colorScheme.primary;
    }

    String timeLabel;
    if (event.allDay == true) {
      timeLabel = 'All day';
    } else if (start != null && end != null) {
      timeLabel =
          '${dateFormat.format(start)}  ${timeFormat.format(start)} – ${timeFormat.format(end)}';
    } else if (start != null) {
      timeLabel = '${dateFormat.format(start)}  ${timeFormat.format(start)}';
    } else {
      timeLabel = '';
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (event.id.isNotEmpty) {
            context.push('/schedule/${event.id}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: eventColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 12, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            timeLabel,
                            style: textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (event.description != null &&
                        event.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.description!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.outline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Count badge ───────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
