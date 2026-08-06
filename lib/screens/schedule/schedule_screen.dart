import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_event.dart';
import '../../providers/providers.dart';
import '../../components/curved_header.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  bool _isMonthlyView = true;

  List<CalendarEvent> _eventsForDay(List<CalendarEvent> events, DateTime day) {
    return events.where((e) {
      final start = DateTime.tryParse(e.start);
      if (start == null) return false;
      return start.year == day.year &&
          start.month == day.month &&
          start.day == day.day;
    }).toList();
  }

  bool _hasEventsForDay(List<CalendarEvent> events, DateTime day) {
    return events.any((e) {
      final start = DateTime.tryParse(e.start);
      if (start == null) return false;
      return start.year == day.year &&
          start.month == day.month &&
          start.day == day.day;
    });
  }

  List<DateTime> _daysInCurrentWeek(DateTime day) {
    // Find the Monday of the week containing 'day'
    final weekdayOffset = day.weekday - 1; // Monday is 1, Sunday is 7.
    final monday = day.subtract(Duration(days: weekdayOffset));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  List<DateTime> _daysInMonth(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final weekdayOfFirst = firstDayOfMonth.weekday; // Monday is 1, Sunday is 7
    final startOffset = weekdayOfFirst - 1; // Days of previous month to show
    final startDate = firstDayOfMonth.subtract(Duration(days: startOffset));
    return List.generate(42, (index) => startDate.add(Duration(days: index)));
  }

  void _prevMonth() {
    setState(() {
      final prevMonth = DateTime(_selectedDay.year, _selectedDay.month - 1, 1);
      final daysInPrev = DateUtils.getDaysInMonth(prevMonth.year, prevMonth.month);
      final day = _selectedDay.day > daysInPrev ? daysInPrev : _selectedDay.day;
      _selectedDay = DateTime(prevMonth.year, prevMonth.month, day);
    });
  }

  void _nextMonth() {
    setState(() {
      final nextMonth = DateTime(_selectedDay.year, _selectedDay.month + 1, 1);
      final daysInNext = DateUtils.getDaysInMonth(nextMonth.year, nextMonth.month);
      final day = _selectedDay.day > daysInNext ? daysInNext : _selectedDay.day;
      _selectedDay = DateTime(nextMonth.year, nextMonth.month, day);
    });
  }

  void _prevWeek() {
    setState(() {
      _selectedDay = _selectedDay.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _selectedDay = _selectedDay.add(const Duration(days: 7));
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scheduleAsync = ref.watch(scheduleStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final weekDays = _daysInCurrentWeek(_selectedDay);

    return Scaffold(
      backgroundColor: Colors.transparent, // Let global mesh gradient flow underneath
      body: Column(
        children: [
          // Top curved header
          CurvedHeader(
            title: 'Schedule',
            onMenuPressed: () => openDrawer(ref),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => context.push('/schedule/new'),
              ),
            ],
          ),

          // Main body content
          Expanded(
            child: scheduleAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: colorScheme.error))),
              data: (events) {
                final dayEvents = _eventsForDay(events, _selectedDay)
                  ..sort((a, b) {
                    final da = DateTime.tryParse(a.start);
                    final db = DateTime.tryParse(b.start);
                    if (da == null || db == null) return 0;
                    return da.compareTo(db);
                  });

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Weekly/Monthly Date Slider Card ──
                    Card(
                      elevation: 0,
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        onPressed: _prevMonth,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          DateFormat('MMMM yyyy').format(_selectedDay),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        onPressed: _nextMonth,
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(_isMonthlyView ? LucideIcons.calendarDays : LucideIcons.calendarDays),
                                      tooltip: _isMonthlyView ? 'Show Week View' : 'Show Month View',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      onPressed: () => setState(() => _isMonthlyView = !_isMonthlyView),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        final now = DateTime.now();
                                        setState(() {
                                          _selectedDay = DateTime(now.year, now.month, now.day);
                                        });
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                        child: Text(
                                          'Today',
                                          style: TextStyle(
                                            color: Color(0xFFF4781F),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (!_isMonthlyView)
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left, size: 20),
                                    onPressed: _prevWeek,
                                  ),
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: weekDays.map((day) {
                                        final isSelected = day.year == _selectedDay.year &&
                                            day.month == _selectedDay.month &&
                                            day.day == _selectedDay.day;
                                        final isToday = day.year == DateTime.now().year &&
                                            day.month == DateTime.now().month &&
                                            day.day == DateTime.now().day;
                                        final hasEvents = _hasEventsForDay(events, day);

                                        return Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2),
                                            child: InkWell(
                                              onTap: () => setState(() => _selectedDay = day),
                                              borderRadius: BorderRadius.circular(100),
                                              child: Container(
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? const Color(0xFFF4781F)
                                                      : (isToday
                                                          ? const Color(0xFFF4781F).withValues(alpha: 0.12)
                                                          : Colors.transparent),
                                                  borderRadius: BorderRadius.circular(100),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      DateFormat('E').format(day).substring(0, 3),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: isSelected
                                                            ? Colors.white
                                                            : (isToday ? const Color(0xFFF4781F) : (isDark ? Colors.white60 : Colors.black54)),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${day.day}',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w800,
                                                        color: isSelected
                                                            ? Colors.white
                                                            : (isToday ? const Color(0xFFF4781F) : (isDark ? Colors.white : Colors.black87)),
                                                      ),
                                                    ),
                                                    if (hasEvents) ...[
                                                      const SizedBox(height: 2),
                                                      Container(
                                                        width: 4,
                                                        height: 4,
                                                        decoration: BoxDecoration(
                                                          color: isSelected ? Colors.white : const Color(0xFFF4781F),
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right, size: 20),
                                    onPressed: _nextWeek,
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  // Weekday headers
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((label) {
                                        return SizedBox(
                                          width: 36,
                                          child: Text(
                                            label,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 7,
                                      mainAxisSpacing: 6,
                                      crossAxisSpacing: 6,
                                      childAspectRatio: 1,
                                    ),
                                    itemCount: 42,
                                    itemBuilder: (context, index) {
                                      final day = _daysInMonth(_selectedDay)[index];
                                      final isSelected = day.year == _selectedDay.year &&
                                          day.month == _selectedDay.month &&
                                          day.day == _selectedDay.day;
                                      final isToday = day.year == DateTime.now().year &&
                                          day.month == DateTime.now().month &&
                                          day.day == DateTime.now().day;
                                      final isCurrentMonth = day.month == _selectedDay.month;
                                      final hasEvents = _hasEventsForDay(events, day);

                                      return InkWell(
                                        onTap: () => setState(() => _selectedDay = day),
                                        borderRadius: BorderRadius.circular(100),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFFF4781F)
                                                : (isToday
                                                    ? const Color(0xFFF4781F).withValues(alpha: 0.12)
                                                    : Colors.transparent),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Text(
                                                '${day.day}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : (isToday
                                                          ? const Color(0xFFF4781F)
                                                          : (isCurrentMonth
                                                              ? (isDark ? Colors.white : Colors.black87)
                                                              : (isDark ? Colors.white30 : Colors.black26))),
                                                ),
                                              ),
                                              if (hasEvents)
                                                Positioned(
                                                  bottom: 4,
                                                  child: Container(
                                                    width: 4,
                                                    height: 4,
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? Colors.white : const Color(0xFFF4781F),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Schedule Timeline Card ──
                    Card(
                      elevation: 0,
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Timeline for ${DateFormat('MMMM d').format(_selectedDay)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (dayEvents.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32.0),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey[400]),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No jobs scheduled',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Tap + in the header to schedule a new job.',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: dayEvents.length,
                                itemBuilder: (context, index) {
                                  final event = dayEvents[index];
                                  final isLast = index == dayEvents.length - 1;
                                  return _TimelineRow(
                                    event: event,
                                    isLast: isLast,
                                    isDark: isDark,
                                    colorScheme: colorScheme,
                                  );
                                },
                              ),
                          ],
                        ),
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
}

class _TimelineRow extends StatelessWidget {
  final CalendarEvent event;
  final bool isLast;
  final bool isDark;
  final ColorScheme colorScheme;

  const _TimelineRow({
    required this.event,
    required this.isLast,
    required this.isDark,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(event.start);
    final end = DateTime.tryParse(event.end);
    final timeFormat = DateFormat('hh:mm a');

    String timeLabel = '';
    if (event.allDay == true) {
      timeLabel = 'All day';
    } else if (start != null) {
      timeLabel = timeFormat.format(start);
    }

    final isWarning = event.title.toLowerCase().contains('job') ||
        event.title.toLowerCase().contains('wall') ||
        (event.description?.toLowerCase().contains('progress') ?? false);

    // Color code processing
    Color eventColor;
    try {
      eventColor = event.color != null
          ? Color(int.parse(event.color!.replaceFirst('#', '0xff')))
          : const Color(0xFFF4781F);
    } catch (_) {
      eventColor = const Color(0xFFF4781F);
    }

    // Build the Card component depending on status
    Widget eventCard;
    if (isWarning) {
      eventCard = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF332014) : const Color(0xFFFFF0E6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF4781F).withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFFE65C00),
                    ),
                  ),
                ),
                const Icon(Icons.warning, color: Color(0xFFE65C00), size: 18),
              ],
            ),
            if (event.description != null && event.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                event.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE65C00).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: Color(0xFFE65C00), shape: BoxShape.circle),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'IN PROGRESS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE65C00),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      eventCard = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (event.description != null && event.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                event.description!,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
              ),
            ],
            if (start != null && end != null && event.allDay != true) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 13, color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 6),
                  Text(
                    '${timeFormat.format(start)} – ${timeFormat.format(end)}',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Column
          Container(
            width: 75,
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              timeLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          // Timeline connector
          SizedBox(
            width: 32,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!isLast)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 24),
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isWarning ? const Color(0xFFF4781F) : eventColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: GestureDetector(
                onTap: () {
                  if (event.id.isNotEmpty) {
                    context.push('/schedule/${event.id}');
                  }
                },
                child: eventCard,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
