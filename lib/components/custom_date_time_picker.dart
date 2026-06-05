import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDateTimePickerSheet extends StatefulWidget {
  final DateTime initialDateTime;
  final String title;

  const CustomDateTimePickerSheet({
    super.key,
    required this.initialDateTime,
    this.title = 'Select Date & Time',
  });

  @override
  State<CustomDateTimePickerSheet> createState() => _CustomDateTimePickerSheetState();
}

class _CustomDateTimePickerSheetState extends State<CustomDateTimePickerSheet> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDateTime;
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
  }

  List<DateTime> _generateDaysInMonth(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final dayOfWeekOfFirst = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun
    
    // Sunday as the first column (0 = Sun, 6 = Sat)
    final offset = dayOfWeekOfFirst == 7 ? 0 : dayOfWeekOfFirst;
    
    final days = <DateTime>[];
    
    // Add prefix days from previous month
    final prevMonth = DateTime(month.year, month.month - 1, 1);
    final daysInPrevMonth = DateUtils.getDaysInMonth(prevMonth.year, prevMonth.month);
    for (int i = offset - 1; i >= 0; i--) {
      days.add(DateTime(prevMonth.year, prevMonth.month, daysInPrevMonth - i));
    }
    
    // Add current month days
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(month.year, month.month, i));
    }
    
    // Add suffix days for next month to complete the 6-week grid (42 cells)
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    final remaining = 42 - days.length;
    for (int i = 1; i <= remaining; i++) {
      days.add(DateTime(nextMonth.year, nextMonth.month, i));
    }
    
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final days = _generateDaysInMonth(_currentMonth);
    final monthName = DateFormat('MMMM yyyy').format(_currentMonth);

    // Generate time options for the dropdown
    final timeOptions = <TimeOfDay>[];
    for (int hour = 0; hour < 24; hour++) {
      timeOptions.add(TimeOfDay(hour: hour, minute: 0));
      timeOptions.add(TimeOfDay(hour: hour, minute: 30));
    }

    // Format helper for display
    String formatTimeOfDay(TimeOfDay tod) {
      final hour = tod.hour == 0 || tod.hour == 12 ? 12 : tod.hour % 12;
      final period = tod.hour < 12 ? 'AM' : 'PM';
      final minuteStr = tod.minute.toString().padLeft(2, '0');
      return '$hour:$minuteStr $period';
    }

    // Find closest TimeOfDay to _selectedTime in our options
    TimeOfDay selectedOption = timeOptions.firstWhere(
      (tod) => tod.hour == _selectedTime.hour && tod.minute == _selectedTime.minute,
      orElse: () {
        final minutes = _selectedTime.minute < 15 ? 0 : (_selectedTime.minute < 45 ? 30 : 0);
        final hour = _selectedTime.minute >= 45 ? (_selectedTime.hour + 1) % 24 : _selectedTime.hour;
        return TimeOfDay(hour: hour, minute: minutes);
      },
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grab handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Calendar Header: Month Name + Chevrons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthName,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Day headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((day) {
              return Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 10,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          SizedBox(
            height: 220,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final date = days[index];
                final isCurrentMonth = date.month == _currentMonth.month;
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      if (date.month != _currentMonth.month) {
                        _currentMonth = DateTime(date.year, date.month, 1);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0xFF00966C) // Premium green selector from mockup
                          : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isCurrentMonth
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark ? Colors.white12 : Colors.black12)),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Select Time Dropdown
          Text(
            'Select Time',
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<TimeOfDay>(
            initialValue: selectedOption,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline),
              ),
            ),
            items: timeOptions.map((tod) {
              return DropdownMenuItem<TimeOfDay>(
                value: tod,
                child: Text(formatTimeOfDay(tod)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedTime = val;
                });
              }
            },
          ),
          const SizedBox(height: 24),

          // Continue Button
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF005F43), // Deep emerald matching standard UAT styling
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final finalDateTime = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                _selectedTime.hour,
                _selectedTime.minute,
              );
              Navigator.pop(context, finalDateTime);
            },
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
