import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDateTimePickerSheet extends StatefulWidget {
  const CustomDateTimePickerSheet(
      {super.key,
      required this.initialDateTime,
      this.title = 'Select date & time'});
  final DateTime initialDateTime;
  final String title;
  @override
  State<CustomDateTimePickerSheet> createState() =>
      _CustomDateTimePickerSheetState();
}

class _CustomDateTimePickerSheetState extends State<CustomDateTimePickerSheet> {
  late DateTime _month;
  late DateTime _date;
  late TimeOfDay _time;
  @override
  void initState() {
    super.initState();
    _date = widget.initialDateTime;
    _month = DateTime(_date.year, _date.month);
    _time = TimeOfDay.fromDateTime(_date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final offset = _month.weekday % 7;
    final firstCell = DateTime(_month.year, _month.month, 1 - offset);
    final cellHeight =
        math.max(48.0, MediaQuery.textScalerOf(context).scale(14) + 20);
    return Material(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(widget.title,
                              style: theme.textTheme.titleLarge)),
                      IconButton(
                          tooltip: 'Close date picker',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: Text(DateFormat.yMMMM().format(_month),
                              style: theme.textTheme.titleMedium)),
                      IconButton(
                          tooltip: 'Previous month',
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setState(() => _month =
                              DateTime(_month.year, _month.month - 1))),
                      IconButton(
                          tooltip: 'Next month',
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setState(() => _month =
                              DateTime(_month.year, _month.month + 1))),
                    ]),
                    const SizedBox(height: 8),
                    Row(
                        children: List.generate(
                            7,
                            (index) => Expanded(
                                child: Text(
                                    DateFormat.E()
                                        .format(DateTime(2026, 9, 6 + index)),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                        color: colors.onSurfaceVariant))))),
                    const SizedBox(height: 8),
                    GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7, mainAxisExtent: cellHeight),
                        itemCount: 42,
                        itemBuilder: (context, index) {
                          final date = DateTime(firstCell.year, firstCell.month,
                              firstCell.day + index);
                          final selected = DateUtils.isSameDay(date, _date);
                          return Semantics(
                              label: DateFormat.yMMMMEEEEd().format(date),
                              selected: selected,
                              button: true,
                              child: ExcludeSemantics(
                                  child: Material(
                                      color: selected
                                          ? colors.primary
                                          : Colors.transparent,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => setState(() {
                                          _date = date;
                                          _month =
                                              DateTime(date.year, date.month);
                                        }),
                                        child: Center(
                                            child: Text('${date.day}',
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                        fontWeight: selected
                                                            ? FontWeight.w700
                                                            : FontWeight.w400,
                                                        color: selected
                                                            ? colors.onPrimary
                                                            : date.month ==
                                                                    _month.month
                                                                ? colors
                                                                    .onSurface
                                                                : colors
                                                                    .onSurfaceVariant))),
                                      ))));
                        }),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text('Time: ${_time.format(context)}'),
                        onPressed: () async {
                          final time = await showTimePicker(
                              context: context, initialTime: _time);
                          if (time != null && mounted)
                            setState(() => _time = time);
                        }),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: () => Navigator.pop(
                            context,
                            DateTime(_date.year, _date.month, _date.day,
                                _time.hour, _time.minute)),
                        child: const Text('Continue')),
                  ]),
            )));
  }
}
