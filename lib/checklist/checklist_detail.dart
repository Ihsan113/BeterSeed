import 'checklist_pickers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/habit.dart';
import '../l10n/app_localizations.dart';
import 'checklist_calendar.dart';
import 'checklist_data.dart';
import 'checklist_style.dart';
import 'habit_icons.dart';

class ChecklistDetail extends StatefulWidget {
  const ChecklistDetail(
      {super.key,
      required this.habit,
      required this.date,
      required this.onChanged,
      required this.onEdit,
      this.onStartFocus,
      this.onActions});
  final Habit habit;
  final DateTime date;
  final ValueChanged<Habit> onChanged;
  final VoidCallback onEdit;
  final VoidCallback? onStartFocus, onActions;

  @override
  State<ChecklistDetail> createState() => _ChecklistDetailState();
}

class _ChecklistDetailState extends State<ChecklistDetail> {
  late Habit habit = widget.habit;

  @override
  Widget build(BuildContext context) =>
      ChecklistSurface(child: Builder(builder: (context) {
        final now = DateTime.now();
        final today = checklistDay(widget.date) == checklistDay(now);
        final data = habit.checklist ?? ChecklistData(start: checklistDay(now));
        var record =
            today ? data.today(now) : data.records[checklistDay(widget.date)];
        if (today && habit.checklist == null && habit.completed) {
          record = record!.change(value: record.plan.target);
        }
        final r = record;
        final editable = today && r != null && r.scheduled && !r.rest;
        final locale = Localizations.localeOf(context).toLanguageTag();
        final plan = r?.plan ?? data.planOn(checklistDay(widget.date));
        final streak = data.streak(now);
        final best = data.streak(now, best: true);
        final status = r == null
            ? 'Unknown'
            : today && r.status == 'Missed'
                ? 'Not completed'
                : r.status;
        void setValue(int value) {
          if (!editable) return;
          final next = r.change(
              value: value.clamp(
                  0, r.plan.type == 'count' ? r.plan.target : 100000));
          setState(() => habit = habit.copyWith(
              completed: next.done, checklist: data.record(now, next)));
          widget.onChanged(habit);
        }

        return Scaffold(
          appBar: AppBar(title: Text(context.tr('Habit details')), actions: [
            if (today && widget.onActions != null)
              IconButton(
                  tooltip: context.tr('Habit actions'),
                  onPressed: widget.onActions,
                  icon: const Icon(Icons.more_horiz)),
            if (today)
              IconButton(
                  tooltip: context.tr('Edit habit'),
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined)),
          ]),
          body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(20), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: checklistBorder,
                      borderRadius: BorderRadius.circular(16)),
                  child: Icon(habitIcon(habit.iconKey),
                      color: checklistPrimary, size: 28)),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(habit.title,
                        style: const TextStyle(
                            fontSize: 24,
                            height: 1.25,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(context.tr(data.category),
                        style: const TextStyle(color: checklistMuted)),
                  ])),
            ]),
            const SizedBox(height: 24),
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: checklistSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: checklistBorder)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat.yMMMd(locale).format(widget.date),
                          style: const TextStyle(
                              color: checklistMuted, fontSize: 12)),
                      const SizedBox(height: 12),
                      Text(
                          plan.type == 'checkbox' || r == null
                              ? context.tr(status)
                              : '${r.value} / ${plan.target}',
                          style: const TextStyle(
                              fontSize: 32, fontWeight: FontWeight.w600)),
                      if (plan.type != 'checkbox' && r != null) ...[
                        Text(
                            plan.type == 'duration'
                                ? context.tr('minutes')
                                : plan.unit == 'count'
                                    ? context.tr('Count')
                                    : plan.unit,
                            style: const TextStyle(color: checklistMuted)),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                            value: (r.value / plan.target).clamp(0, 1),
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(3),
                            backgroundColor: checklistBorder,
                            color: checklistPrimary),
                      ],
                      if (editable) ...[
                        const SizedBox(height: 20),
                        if (plan.type == 'checkbox')
                          FilledButton.icon(
                              onPressed: () => setValue(r.done ? 0 : 1),
                              icon: Icon(r.done
                                  ? Icons.undo_rounded
                                  : Icons.check_rounded),
                              label: Text(
                                  context.tr(r.done ? 'Undo' : 'Complete')))
                        else if (plan.type == 'duration')
                          FilledButton.icon(
                              onPressed: widget.onStartFocus,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(context.tr('Start focus')))
                        else
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton(
                                onPressed: r.value == 0
                                    ? null
                                    : () => setValue(r.value - 1),
                                child: Icon(Icons.remove,
                                    semanticLabel: context.tr('Decrease'))),
                            OutlinedButton(
                                onPressed:
                                    r.done ? null : () => setValue(r.value + 1),
                                child: const Text('+1')),
                            OutlinedButton(
                                onPressed: () async {
                                  final value = await NumericGoalSheet.show(
                                      context, r.value,
                                      minimum: 0,
                                      maximum: plan.target,
                                      title: 'Set progress');
                                  if (value != null && mounted) setValue(value);
                                },
                                child: Text(context.tr('Set progress'))),
                            if (!r.done)
                              FilledButton(
                                  onPressed: () => setValue(plan.target),
                                  child: Text(context.tr('Complete'))),
                          ]),
                      ],
                    ])),
            if (!today)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                      context.tr(
                          'History is read-only. Missing records are unknown.'),
                      style: const TextStyle(
                          color: checklistMuted, fontSize: 12))),
            const SizedBox(height: 28),
            Text(context.tr('Schedule'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(
                plan.weekdays
                    .map((i) =>
                        DateFormat.E(locale).format(DateTime(2026, 11, 1 + i)))
                    .join(' · '),
                style: const TextStyle(color: checklistMuted, height: 1.6)),
            const SizedBox(height: 8),
            Text(
                plan.activityMinute == null
                    ? context.tr('Anytime')
                    : clockLabel(context, plan.activityMinute!),
                style: const TextStyle(color: checklistPrimary)),
            if (habit.reminderEnabled)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    const Icon(Icons.notifications_none_rounded,
                        size: 18, color: checklistMuted),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(plan.activityMinute == null
                            ? clockLabel(context,
                                habit.reminderHour * 60 + habit.reminderMinute)
                            : context.tr(
                                habit.reminderLeadMinutes == 0
                                    ? 'At activity time'
                                    : '{p0} min before',
                                {'p0': habit.reminderLeadMinutes}))),
                  ])),
            const SizedBox(height: 28),
            Text(context.tr('Scheduled habit streak: {p0}', {'p0': streak}),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final milestone in [7, 30, 100])
                Chip(
                    avatar: Icon(
                        best >= milestone
                            ? Icons.emoji_events_outlined
                            : Icons.lock_outline,
                        size: 18,
                        color: best >= milestone
                            ? const Color(0xFFD7B98B)
                            : checklistMuted),
                    label: Text(
                        context.tr('{p0} completions', {'p0': milestone}))),
            ]),
            const SizedBox(height: 28),
            Text(context.tr('History'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (data.records.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(context.tr('Unknown'),
                      style: const TextStyle(color: checklistMuted))),
            for (final key in (data.records.keys.toList()..sort()).reversed)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                      data.records[key]!.done
                          ? Icons.check_rounded
                          : Icons.horizontal_rule,
                      size: 18,
                      color: historyColors[data.records[key]!.status]),
                  title: Text(
                      DateFormat.yMMMd(locale).format(DateTime.parse(key))),
                  subtitle: Text(context.tr(data.records[key]!.status)),
                  trailing: Text(
                      '${data.records[key]!.value}/${data.records[key]!.plan.target}',
                      style: const TextStyle(color: checklistMuted))),
          ])),
        );
      }));
}
