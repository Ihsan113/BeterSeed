import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/habit.dart';
import '../l10n/app_localizations.dart';
import 'checklist_data.dart';

const historyColors = {
  'Done': Color(0xFF96E4B2),
  'Partial': Color(0xFF72CEF0),
  'Missed': Color(0xFFF08C88),
  'Rest': Color(0xFFC7AAEB),
  'Not scheduled': Color(0xFFBBCFC7),
  'Not completed': Color(0xFFBBCFC7),
  'Unknown': Color(0xFF78918C)
};
String historyStatus(List<Habit> habits, String day) {
  final records = habits
      .map((h) => h.checklist?.records[day])
      .whereType<HabitRecord>()
      .toList();
  if (records.isEmpty) return 'Unknown';
  final scheduled = records.where((r) => r.scheduled && !r.rest).toList();
  if (scheduled.isEmpty)
    return records.any((r) => r.rest) ? 'Rest' : 'Not scheduled';
  if (scheduled.every((r) => r.done)) return 'Done';
  if (scheduled.any((r) => r.value > 0)) return 'Partial';
  return day == checklistDay(DateTime.now()) ? 'Not completed' : 'Missed';
}

class ChecklistCalendar extends StatefulWidget {
  const ChecklistCalendar(
      {super.key, required this.habits, required this.initial});
  final List<Habit> habits;
  final DateTime initial;
  @override
  State<ChecklistCalendar> createState() => _ChecklistCalendarState();
}

class _ChecklistCalendarState extends State<ChecklistCalendar> {
  late DateTime month;
  @override
  void initState() {
    super.initState();
    month = DateTime(widget.initial.year, widget.initial.month);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final offset = month.weekday - 1;
    final length = DateTime(month.year, month.month + 1, 0).day;
    return Scaffold(
        appBar: AppBar(title: Text(context.tr('Calendar'))),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            IconButton(
                tooltip: context.tr('Back'),
                onPressed: () => setState(
                    () => month = DateTime(month.year, month.month - 1)),
                icon: const Icon(Icons.chevron_left)),
            Expanded(
                child: Text(DateFormat.yMMMM(locale).format(month),
                    textAlign: TextAlign.center)),
            IconButton(
                tooltip: context.tr('Continue'),
                onPressed: month.year == now.year && month.month == now.month
                    ? null
                    : () => setState(
                        () => month = DateTime(month.year, month.month + 1)),
                icon: const Icon(Icons.chevron_right))
          ]),
          LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                      width: constraints.maxWidth < 336
                          ? 336
                          : constraints.maxWidth,
                      child: Column(children: [
                        Row(children: [
                          for (var i = 0; i < 7; i++)
                            Expanded(
                                child: Text(
                                    DateFormat.E(locale)
                                        .format(DateTime(2026, 11, 2 + i)),
                                    textAlign: TextAlign.center))
                        ]),
                        for (var week = 0;
                            week < (offset + length + 6) ~/ 7;
                            week++)
                          Row(children: [
                            for (var weekday = 0; weekday < 7; weekday++)
                              Expanded(child: Builder(builder: (context) {
                                final number = week * 7 + weekday - offset + 1;
                                if (number < 1 || number > length)
                                  return const SizedBox(height: 48);
                                final date =
                                    DateTime(month.year, month.month, number);
                                final status = historyStatus(
                                    widget.habits, checklistDay(date));
                                return Semantics(
                                    label:
                                        '${DateFormat.yMMMd(locale).format(date)}, ${context.tr(status)}',
                                    child: TextButton(
                                        onPressed: date.isAfter(today)
                                            ? null
                                            : () =>
                                                Navigator.pop(context, date),
                                        style: TextButton.styleFrom(
                                            minimumSize: const Size(48, 56),
                                            foregroundColor:
                                                historyColors[status]),
                                        child: Column(children: [
                                          Text('$number'),
                                          Icon(
                                              status == 'Done'
                                                  ? Icons.check_circle
                                                  : status == 'Rest'
                                                      ? Icons.pause_circle
                                                      : status == 'Partial'
                                                          ? Icons.timelapse
                                                          : status == 'Unknown'
                                                              ? Icons
                                                                  .help_outline
                                                              : Icons
                                                                  .circle_outlined,
                                              size: 16)
                                        ])));
                              }))
                          ]),
                      ])))),
          Wrap(spacing: 8, children: [
            for (final entry in historyColors.entries)
              Chip(
                  avatar: Icon(Icons.circle, size: 14, color: entry.value),
                  label: Text(context.tr(entry.key)))
          ]),
          Text(
              context.tr('History is read-only. Missing records are unknown.')),
        ])));
  }
}
