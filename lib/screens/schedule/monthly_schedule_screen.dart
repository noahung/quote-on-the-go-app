import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_event.dart';
import '../../providers/providers.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';

class MonthlyScheduleScreen extends ConsumerStatefulWidget {
  const MonthlyScheduleScreen({super.key});

  @override
  ConsumerState<MonthlyScheduleScreen> createState() =>
      _MonthlyScheduleScreenState();
}

class _MonthlyScheduleScreenState extends ConsumerState<MonthlyScheduleScreen> {
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  DateTime? _selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
      _selectedDay = null;
    });
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

  List<CalendarEvent> _eventsForSelectedOrAll(List<CalendarEvent> events) {
    if (_selectedDay != null) {
      return _eventsForDay(events, _selectedDay!);
    }
    return events.where((e) {
      final start = DateTime.tryParse(e.start);
      if (start == null) return false;
      return start.year == _focusedMonth.year &&
          start.month == _focusedMonth.month;
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a.start);
        final db = DateTime.tryParse(b.start);
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final scheduleAsync = ref.watch(scheduleStreamProvider);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Monthly Schedule',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
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
          final selectedEvents = _eventsForSelectedOrAll(events);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      // Month navigator header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _previousMonth,
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(_focusedMonth),
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                      ),
                      // Day-of-week headers
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                              .map((d) => Expanded(
                                    child: Center(
                                      child: Text(
                                        d,
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Calendar grid
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _CalendarGrid(
                          focusedMonth: _focusedMonth,
                          selectedDay: _selectedDay,
                          events: events,
                          onDaySelected: (day) {
                            setState(() {
                              _selectedDay = _selectedDay?.isAtSameMomentAs(day) == true
                                  ? null
                                  : day;
                            });
                          },
                          eventsForDay: _eventsForDay,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Event list for selected day / month
              Expanded(
                child: selectedEvents.isEmpty
                    ? Center(
                        child: Text(
                          _selectedDay != null
                              ? 'No events on ${DateFormat('MMM d').format(_selectedDay!)}'
                              : 'No events this month',
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: selectedEvents.length,
                        itemBuilder: (context, i) =>
                            _EventListTile(event: selectedEvents[i]),
                      ),
              ),
            ],
          );
        },
      ),
    ));
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final List<CalendarEvent> events;
  final void Function(DateTime) onDaySelected;
  final List<CalendarEvent> Function(List<CalendarEvent>, DateTime)
      eventsForDay;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.events,
    required this.onDaySelected,
    required this.eventsForDay,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now();

    // First day of month, offset to Monday-based week
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final startOffset = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth =
        DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

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
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const SizedBox.shrink();
        }

        final day = DateTime(focusedMonth.year, focusedMonth.month, dayNum);
        final isToday = day.year == today.year &&
            day.month == today.month &&
            day.day == today.day;
        final isSelected = selectedDay != null &&
            day.year == selectedDay!.year &&
            day.month == selectedDay!.month &&
            day.day == selectedDay!.day;
        final dayEvents = eventsForDay(events, day);
        final hasEvents = dayEvents.isNotEmpty;

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
                if (hasEvents)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                      ),
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

class _EventListTile extends StatelessWidget {
  final CalendarEvent event;
  const _EventListTile({required this.event});

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

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
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
                  if (event.allDay == true)
                    Text('All day',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant))
                  else if (start != null)
                    Text(
                      end != null
                          ? '${dateFormat.format(start)}  ${timeFormat.format(start)} – ${timeFormat.format(end)}'
                          : '${dateFormat.format(start)}  ${timeFormat.format(start)}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
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
          ],
        ),
      ),
    );
  }
}
