import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../data/habit.dart';
import '../l10n/app_localizations.dart';
import 'checklist_data.dart';
import 'checklist_pickers.dart';
import 'checklist_style.dart';
import 'habit_icons.dart';

class HabitEditor extends StatefulWidget {
  const HabitEditor(
      {super.key,
      this.initial,
      required this.creating,
      required this.masterEnabled,
      required this.onEnableMaster});
  final Habit? initial;
  final bool creating, masterEnabled;
  final Future<bool> Function() onEnableMaster;
  @override
  State<HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends State<HabitEditor> {
  late final TextEditingController title;
  final iconScroll = ScrollController();
  final form = GlobalKey<FormState>();
  late String icon, category, type, legacyUnit;
  late int target;
  late Set<int> days;
  late int? activity;
  late ReminderChoice reminder;
  late bool master;
  int step = 0;
  String query = '', iconCategory = 'All';
  @override
  void initState() {
    super.initState();
    final h = widget.initial;
    final d = h?.checklist;
    final p = d?.pending ?? d?.plan ?? const HabitPlan();
    title = TextEditingController(text: h?.title ?? '');
    icon = h?.iconKey ?? 'leaf';
    category = d?.category ?? 'Morning';
    type = p.type;
    target = p.target;
    legacyUnit = p.unit;
    days = p.weekdays.toSet();
    activity = p.activityMinute;
    reminder = ReminderChoice(
        h?.reminderEnabled ?? false,
        (h?.reminderHour ?? 20) * 60 + (h?.reminderMinute ?? 0),
        h?.reminderLeadMinutes ?? 0);
    master = widget.masterEnabled;
  }

  @override
  void dispose() {
    title.dispose();
    iconScroll.dispose();
    super.dispose();
  }

  void save() {
    final now = DateTime.now();
    final p = HabitPlan(
        type: type,
        target: type == 'checkbox' ? 1 : target,
        unit: type == 'count'
            ? (legacyUnit.trim().isEmpty ? 'count' : legacyUnit)
            : '',
        weekdays: days.toList()..sort(),
        activityMinute: activity);
    // Never materialize a checkbox record before the user's chosen plan exists.
    final data = widget.creating
        ? ChecklistData(start: checklistDay(now), plan: p, category: category)
            .advance(now)
        : (widget.initial!.checklist ?? ChecklistData(start: checklistDay(now)))
            .advance(now)
            .edit(p, now)
            .copy(category: category);
    Navigator.pop(
        context,
        Habit(
            id: widget.creating ? const Uuid().v4() : widget.initial!.id,
            title: title.text.trim(),
            iconKey: icon,
            completed: widget.creating ? false : widget.initial!.completed,
            checklist: data,
            reminderEnabled: reminder.enabled,
            reminderHour: reminder.minute ~/ 60,
            reminderMinute: reminder.minute % 60,
            reminderLeadMinutes: reminder.lead));
  }

  Widget setting(BuildContext context, String label, String value,
          IconData icon, VoidCallback onTap) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
              color: checklistSurface,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(icon, color: checklistPrimary),
                  title: Text(context.tr(label),
                      style:
                          const TextStyle(fontSize: 13, color: checklistMuted)),
                  subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(value,
                          style: const TextStyle(
                              fontSize: 15, color: checklistText))),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: onTap)));

  @override
  Widget build(BuildContext context) => ChecklistSurface(
      child: Builder(
          builder: (context) => Scaffold(
                appBar: AppBar(
                    title: Text(context.tr(
                        widget.creating ? 'Plant a new habit' : 'Edit habit'))),
                body: SafeArea(
                    child: Form(
                        key: form,
                        child: Column(children: [
                          Expanded(
                              child: ListView(
                                  padding: const EdgeInsets.all(20),
                                  children: [
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (var i = 0; i < 2; i++)
                                        Expanded(
                                            child: Padding(
                                                padding: EdgeInsets.only(
                                                    right: i == 0 ? 12 : 0),
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Container(
                                                          height: 3,
                                                          decoration: BoxDecoration(
                                                              color: i <= step
                                                                  ? checklistPrimary
                                                                  : checklistBorder,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          2))),
                                                      const SizedBox(
                                                          height: 12),
                                                      Text(
                                                          context.tr(i == 0
                                                              ? 'Habit information'
                                                              : 'Target & schedule'),
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color: i == step
                                                                  ? checklistText
                                                                  : checklistMuted)),
                                                    ])))
                                    ]),
                                const SizedBox(height: 24),
                                if (step == 0) ...[
                                  TextFormField(
                                      controller: title,
                                      maxLength: 300,
                                      decoration: InputDecoration(
                                          labelText: context.tr('Habit name')),
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                              ? context.tr('Required')
                                              : null),
                                  const SizedBox(height: 16),
                                  setting(
                                      context,
                                      'Category',
                                      context.tr(category),
                                      Icons.grid_view_outlined, () async {
                                    final v = await HabitCategoryPicker.show(
                                        context, category);
                                    if (v != null && mounted)
                                      setState(() => category = v);
                                  }),
                                  const SizedBox(height: 16),
                                  Text(context.tr('Pick an icon'),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 12),
                                  TextField(
                                      decoration: InputDecoration(
                                          labelText: context.tr('Search icons'),
                                          prefixIcon: const Icon(Icons.search)),
                                      onChanged: (v) => setState(
                                          () => query = v.toLowerCase())),
                                  const SizedBox(height: 12),
                                  SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(children: [
                                        for (final c in [
                                          'All',
                                          ...habitIcons
                                              .map((i) => i.category)
                                              .toSet()
                                        ])
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 8),
                                              child: ChoiceChip(
                                                  showCheckmark: false,
                                                  label: Text(context.tr(
                                                      c == 'Legacy'
                                                          ? 'Classic'
                                                          : c)),
                                                  selected: iconCategory == c,
                                                  onSelected: (_) => setState(
                                                      () => iconCategory = c)))
                                      ])),
                                  const SizedBox(height: 12),
                                  ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxHeight: 240),
                                      child: Scrollbar(
                                          controller: iconScroll,
                                          thumbVisibility: true,
                                          child: SingleChildScrollView(
                                              controller: iconScroll,
                                              child: Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    for (final i in habitIcons.where((i) =>
                                                        (iconCategory == 'All' ||
                                                            i.category ==
                                                                iconCategory) &&
                                                        (context
                                                                .tr(i.label)
                                                                .toLowerCase()
                                                                .contains(
                                                                    query) ||
                                                            i.key.contains(
                                                                query))))
                                                      Semantics(
                                                          selected:
                                                              icon == i.key,
                                                          child: IconButton.filledTonal(
                                                              tooltip:
                                                                  context.tr(i.label),
                                                              isSelected: icon == i.key,
                                                              icon: Icon(i.icon),
                                                              onPressed: () => setState(() => icon = i.key),
                                                              style: IconButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: icon == i.key ? const BorderSide(color: checklistPrimary, width: 2) : null))),
                                                  ])))),
                                ] else ...[
                                  GoalTypeSelector(
                                      value: type,
                                      onChanged: (v) => setState(() {
                                            if (v != type) {
                                              type = v;
                                              target = v == 'count'
                                                  ? 8
                                                  : v == 'duration'
                                                      ? 15
                                                      : 1;
                                            }
                                          })),
                                  if (type != 'checkbox') ...[
                                    const SizedBox(height: 12),
                                    setting(
                                        context,
                                        'Target',
                                        '$target${type == 'duration' ? ' ${context.tr('minutes')}' : ''}',
                                        Icons.tune_rounded, () async {
                                      final n = await NumericGoalSheet.show(
                                          context, target);
                                      if (n != null && mounted)
                                        setState(() => target = n);
                                    }),
                                  ],
                                  if (type == 'duration')
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      for (final n in [
                                        5,
                                        10,
                                        15,
                                        20,
                                        30,
                                        45,
                                        60
                                      ])
                                        ChoiceChip(
                                            showCheckmark: false,
                                            label:
                                                Text('$n ${context.tr('min')}'),
                                            selected: target == n,
                                            onSelected: (_) =>
                                                setState(() => target = n))
                                    ]),
                                  const SizedBox(height: 24),
                                  setting(
                                      context,
                                      'Activity days',
                                      days.length == 7
                                          ? context.tr('Every day')
                                          : (days.toList()..sort())
                                              .map((i) => DateFormat.E(
                                                      Localizations.localeOf(
                                                              context)
                                                          .toLanguageTag())
                                                  .format(DateTime(
                                                      2026, 11, 1 + i)))
                                              .join(' · '),
                                      Icons.calendar_today_outlined, () async {
                                    final d = await ScheduleDayPicker.show(
                                        context, days);
                                    if (d != null && mounted)
                                      setState(() => days = d);
                                  }),
                                  setting(
                                      context,
                                      'Activity time',
                                      activity == null
                                          ? context.tr('Anytime')
                                          : clockLabel(context, activity!),
                                      Icons.access_time, () async {
                                    final t = await ActivityTimePicker.show(
                                        context, activity);
                                    if (t != null && mounted)
                                      setState(
                                          () => activity = t < 0 ? null : t);
                                  }),
                                  setting(
                                      context,
                                      'Reminder',
                                      !reminder.enabled
                                          ? context.tr('Off')
                                          : activity == null
                                              ? clockLabel(
                                                  context, reminder.minute)
                                              : context.tr(
                                                  reminder.lead == 0
                                                      ? 'At activity time'
                                                      : '{p0} min before',
                                                  {'p0': reminder.lead}),
                                      Icons.notifications_none_rounded,
                                      () async {
                                    final r = await ReminderPicker.show(
                                        context, reminder, activity);
                                    if (r != null && mounted)
                                      setState(() => reminder = r);
                                  }),
                                  if (reminder.enabled && !master) ...[
                                    Text(
                                        context.tr(
                                            'Master notifications are OFF — reminders will be paused'),
                                        style: const TextStyle(
                                            color: checklistMuted,
                                            fontSize: 12)),
                                    TextButton.icon(
                                        onPressed: () async {
                                          final on =
                                              await widget.onEnableMaster();
                                          if (mounted)
                                            setState(() => master = on);
                                        },
                                        icon: const Icon(Icons
                                            .notifications_active_outlined),
                                        label: Text(context.tr(
                                            'Enable master notifications'))),
                                  ],
                                  if (!widget.creating)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                            context.tr(
                                                'Target and schedule changes start tomorrow.'),
                                            style: const TextStyle(
                                                color: checklistMuted,
                                                fontSize: 12))),
                                ],
                              ])),
                          Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(children: [
                                if (step == 1)
                                  TextButton(
                                      onPressed: () => setState(() => step = 0),
                                      child: Text(context.tr('Back'))),
                                Expanded(
                                    child: FilledButton(
                                        onPressed: () {
                                          if (step == 0) {
                                            if (form.currentState!.validate())
                                              setState(() => step = 1);
                                          } else {
                                            save();
                                          }
                                        },
                                        child: Text(context.tr(step == 0
                                            ? 'Continue'
                                            : 'Save habit')))),
                              ])),
                        ]))),
              )));
}
