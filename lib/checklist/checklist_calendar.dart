import 'checklist_style.dart';
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
    return ChecklistSurface(
        child: Scaffold(
            appBar: AppBar(title: Text(context.tr('Calendar'))),
            body: SafeArea(
                child: ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                IconButton(
                    tooltip: context.tr('Previous month'),
                    onPressed: () => setState(
                        () => month = DateTime(month.year, month.month - 1)),
                    icon: const Icon(Icons.chevron_left)),
                Expanded(
                    child: Text(DateFormat.yMMMM(locale).format(month),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center)),
                IconButton(
                    tooltip: context.tr('Next month'),
                    onPressed:
                        month.year == now.year && month.month == now.month
                            ? null
                            : () => setState(() =>
                                month = DateTime(month.year, month.month + 1)),
                    icon: const Icon(Icons.chevron_right))
              ]),
              const SizedBox(height: 24),
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
                                    final number =
                                        week * 7 + weekday - offset + 1;
                                    if (number < 1 || number > length)
                                      return const SizedBox(height: 48);
                                    final date = DateTime(
                                        month.year, month.month, number);
                                    final status = historyStatus(
                                        widget.habits, checklistDay(date));
                                    return Semantics(
                                        label:
                                            '${DateFormat.yMMMd(locale).format(date)}, ${context.tr(status)}',
                                        child: TextButton(
                                            onPressed: date.isAfter(today)
                                                ? null
                                                : () => Navigator.pop(
                                                    context, date),
                                            style: TextButton.styleFrom(
                                                minimumSize: const Size(48, 56),
                                                backgroundColor:
                                                    checklistDay(date) ==
                                                            checklistDay(
                                                                widget.initial)
                                                        ? checklistBorder
                                                        : Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                                foregroundColor:
                                                    historyColors[status]),
                                            child: Column(children: [
                                              Text('$number'),
                                              const SizedBox(height: 5),
                                              SizedBox(
                                                  height: 12,
                                                  child: status == 'Done'
                                                      ? Icon(
                                                          Icons.check_rounded,
                                                          size: 12,
                                                          color: historyColors[
                                                              status])
                                                      : Center(
                                                          child: Container(
                                                              width: 4,
                                                              height: 4,
                                                              decoration: BoxDecoration(
                                                                  color: date.isAfter(
                                                                          today)
                                                                      ? Colors
                                                                          .transparent
                                                                      : historyColors[
                                                                          status],
                                                                  shape: BoxShape
                                                                      .circle)))),
                                            ])));
                                  }))
                              ]),
                          ])))),
              const SizedBox(height: 24),
              Wrap(spacing: 16, runSpacing: 12, children: [
                for (final entry in historyColors.entries)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: entry.value, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(context.tr(entry.key),
                        style: const TextStyle(
                            fontSize: 12, color: checklistMuted))
                  ])
              ]),
              const SizedBox(height: 24),
              Text(context
                  .tr('History is read-only. Missing records are unknown.')),
            ]))));
  }
}
