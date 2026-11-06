import 'dart:async';
import 'planner_status.dart';
export 'habit_editor.dart';
import 'habit_editor.dart';
import 'checklist_pickers.dart';
import 'checklist_detail.dart';
import 'checklist_style.dart';
import 'checklist_calendar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../data/habit.dart';
import '../logic/water_progress.dart';
import '../l10n/app_localizations.dart';
import 'checklist_data.dart';
import 'habit_icons.dart';

class ChecklistPage extends StatefulWidget {
  const ChecklistPage(
      {super.key,
      required this.habits,
      required this.progress,
      required this.onChanged,
      required this.masterEnabled,
      required this.onEnableMaster,
      this.onOpenSettings,
      this.onStartFocus});
  final VoidCallback? onOpenSettings;
  final ValueChanged<Habit>? onStartFocus;
  final List<Habit> habits;
  final WaterProgress progress;
  final ValueChanged<List<Habit>> onChanged;
  final bool masterEnabled;
  final Future<bool> Function() onEnableMaster;
  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  DateTime selected = DateTime.now();
  Timer? clock;
  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  String filter = 'All';
  String observedDay = checklistDay(DateTime.now());
  @override
  void didUpdateWidget(covariant ChecklistPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final now = DateTime.now();
    if (checklistDay(now) != observedDay) {
      if (day == observedDay) selected = now;
      observedDay = checklistDay(now);
    }
  }

  String get day => checklistDay(selected);
  bool get isToday => day == checklistDay(DateTime.now());
  ChecklistData data(Habit h) =>
      h.checklist ?? ChecklistData(start: checklistDay(DateTime.now()));
  HabitRecord? record(Habit h) {
    if (isToday) {
      final d = data(h);
      final r = d.today(selected);
      return h.checklist == null && h.completed
          ? r.change(value: r.plan.target)
          : r;
    }
    return h.checklist?.records[day];
  }

  void replace(Habit habit) => widget.onChanged([
        for (final h in widget.habits)
          if (h.id == habit.id) habit else h
      ]);
  void change(Habit h, {int? amount, bool? rest}) {
    if (!isToday) return;
    final now = DateTime.now();
    final d = data(h);
    final r = record(h)!;
    if (!r.scheduled || (r.rest && rest == null)) return;
    if (rest == true && widget.progress.wasCredited(day, h.id)) return;
    final next = r.change(
        value:
            amount?.clamp(0, r.plan.type == 'count' ? r.plan.target : 100000),
        rest: rest);
    replace(h.copyWith(completed: next.done, checklist: d.record(now, next)));
  }

  Future<void> compose({Habit? initial, Habit? template}) async {
    final result = await Navigator.of(context).push<Habit>(MaterialPageRoute(
        builder: (_) => HabitEditor(
            initial: initial ?? template,
            creating: initial == null,
            masterEnabled: widget.masterEnabled,
            onEnableMaster: widget.onEnableMaster)));
    if (!mounted || result == null) return;
    if (initial == null) {
      widget.onChanged([...widget.habits, result]);
    } else {
      replace(result);
    }
  }

  Future<void> manageHabits() async {
    final selected = await plannerSheet<Habit>(
        context,
        'Manage habits',
        (context) => Column(children: [
              for (final h in widget.habits.where((h) => !data(h).archived))
                ListTile(
                    leading: Icon(habitIcon(h.iconKey)),
                    title: Text(h.title),
                    subtitle: Text(context.tr(
                        data(h).today(DateTime.now()).scheduled
                            ? data(h).category
                            : 'Not scheduled')),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => Navigator.pop(context, h)),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Close'))),
            ]));
    if (mounted && selected != null) await compose(initial: selected);
  }

  Future<void> calendar() async {
    final value = await Navigator.push<DateTime>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                ChecklistCalendar(habits: widget.habits, initial: selected)));
    if (value != null && mounted) setState(() => selected = value);
  }

  void detail(Habit initial) {
    var latest = initial;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (route) => ChecklistDetail(
                  habit: initial,
                  date: selected,
                  onStartFocus: widget.onStartFocus == null
                      ? null
                      : () {
                          Navigator.pop(route);
                          widget.onStartFocus!(latest);
                        },
                  onActions: () {
                    Navigator.pop(route);
                    _actions(latest, record(latest));
                  },
                  onChanged: (habit) {
                    latest = habit;
                    replace(habit);
                  },
                  onEdit: () {
                    Navigator.pop(route);
                    compose(initial: latest);
                  },
                )));
  }

  Future<void> templates() async {
    final names = [
      'Healthy Morning',
      'Study Focus',
      'Fitness Routine',
      'Self-Care',
      'Sleep Hygiene',
      'Creative Time'
    ];
    final icons = ['hydration', 'study', 'gym', 'meditation', 'sleep', 'art'];
    final choice = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        backgroundColor: checklistBackground,
        builder: (context) => ChecklistSurface(
                child: SafeArea(
                    child: ListView(shrinkWrap: true, children: [
              for (var i = 0; i < names.length; i++)
                ListTile(
                    leading: Icon(habitIcon(icons[i])),
                    title: Text(context.tr(names[i])),
                    subtitle: Text(context.tr('Preview and customize')),
                    onTap: () => Navigator.pop(context, i))
            ]))));
    if (choice == null || !mounted) return;
    final titles = [
      ['Drink water', 'Stretch'],
      ['Read', 'Practice'],
      ['Exercise', 'Stretch'],
      ['Meditate', 'Journal'],
      ['Read', 'Breathe'],
      ['Create', 'Practice']
    ];
    var drafts = [
      for (final name in titles[choice])
        Habit(
            id: const Uuid().v4(),
            title: context.tr(name),
            iconKey: icons[choice],
            checklist: ChecklistData(
                start: checklistDay(DateTime.now()),
                category: choice == 4 ? 'Evening' : 'Morning',
                plan: HabitPlan(
                    type: name == 'Drink water'
                        ? 'count'
                        : name == 'Journal'
                            ? 'checkbox'
                            : 'duration',
                    target: name == 'Drink water'
                        ? 8
                        : name == 'Journal'
                            ? 1
                            : 10,
                    unit: name == 'Drink water' ? context.tr('glasses') : '')))
    ];
    final accepted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (route) => StatefulBuilder(
                builder: (route, update) => ChecklistSurface(
                    child: Scaffold(
                        appBar: AppBar(title: Text(route.tr(names[choice]))),
                        body: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(route.tr('Preview and customize')),
                              for (var i = 0; i < drafts.length; i++)
                                ListTile(
                                    title: Text(drafts[i].title),
                                    subtitle: Text(drafts[i]
                                                .checklist!
                                                .plan
                                                .type ==
                                            'checkbox'
                                        ? route.tr('Check-in')
                                        : '${drafts[i].checklist!.plan.target} ${drafts[i].checklist!.plan.type == 'duration' ? route.tr('minutes') : drafts[i].checklist!.plan.unit}'),
                                    trailing: IconButton(
                                        tooltip: route.tr('Edit habit'),
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () async {
                                          final edited = await Navigator.push<
                                                  Habit>(
                                              route,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      HabitEditor(
                                                          initial: drafts[i],
                                                          creating: true,
                                                          masterEnabled: widget
                                                              .masterEnabled,
                                                          onEnableMaster: widget
                                                              .onEnableMaster)));
                                          if (edited != null && route.mounted)
                                            update(() => drafts[i] = edited);
                                        })),
                              FilledButton(
                                  onPressed: () => Navigator.pop(route, true),
                                  child: Text(route.tr('Add routine'))),
                            ]))))));
    if (accepted == true && mounted)
      widget.onChanged([...widget.habits, ...drafts]);
  }

  bool arranging = false;

  Widget _week(String locale) => LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final minimum = scale > 1.4 ? 64.0 : 44.0;
        final width = constraints.maxWidth < minimum * 7
            ? minimum * 7
            : constraints.maxWidth;
        return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: SizedBox(
                width: width,
                child: Row(children: [
                  for (var i = 6; i >= 0; i--)
                    Expanded(child: Builder(builder: (context) {
                      final now = DateTime.now();
                      final date = DateTime(now.year, now.month, now.day - i);
                      final active = checklistDay(date) == day;
                      final status =
                          historyStatus(widget.habits, checklistDay(date));
                      final ink = active ? checklistBackground : checklistText;
                      return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Semantics(
                            selected: active,
                            button: true,
                            label:
                                '${DateFormat.yMMMd(locale).format(date)}, ${context.tr(status)}',
                            child: Material(
                                color: active
                                    ? checklistPrimary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  key: ValueKey(
                                      'checklist-date-${checklistDay(date)}'),
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setState(() => selected = date),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                                DateFormat.E(locale)
                                                    .format(date),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: active
                                                        ? ink
                                                        : checklistMuted,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            const SizedBox(height: 7),
                                            Text('${date.day}',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: ink)),
                                            const SizedBox(height: 7),
                                            SizedBox(
                                                height: 12,
                                                child: status == 'Done'
                                                    ? Icon(Icons.check_rounded,
                                                        key: ValueKey(
                                                            'day-done-${checklistDay(date)}'),
                                                        size: 12,
                                                        color: ink)
                                                    : status == 'Rest'
                                                        ? Icon(
                                                            Icons
                                                                .horizontal_rule,
                                                            size: 12,
                                                            color: ink)
                                                        : Center(
                                                            child: Container(
                                                                width: 4,
                                                                height: 4,
                                                                decoration: BoxDecoration(
                                                                    color: status == 'Partial'
                                                                        ? const Color(0xFF8CC8DB)
                                                                        : active
                                                                            ? ink
                                                                            : checklistBorder,
                                                                    shape: BoxShape.circle)))),
                                          ])),
                                )),
                          ));
                    })),
                ])));
      });

  Widget _summary(int done, int total) {
    final ratio = total == 0 ? 0.0 : done / total;
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: checklistSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: checklistBorder.withValues(alpha: .65))),
        child: Row(children: [
          SizedBox(
              width: 64,
              height: 64,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                    child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        color: checklistPrimary,
                        backgroundColor: checklistBorder,
                        semanticsLabel: context.tr(
                            '{p0}/{p1} habits', {'p0': done, 'p1': total}))),
                Text('${(ratio * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ])),
          const SizedBox(width: 18),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    total == 0
                        ? context.tr('No habits scheduled')
                        : context
                            .tr('{p0}/{p1} habits', {'p0': done, 'p1': total}),
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.4)),
                const SizedBox(height: 10),
                Wrap(spacing: 14, runSpacing: 8, children: [
                  _metric(
                      Icons.water_drop_outlined,
                      context.tr(
                          '{p0} water', {'p0': widget.progress.earnedOn(day)}),
                      const Color(0xFF8CC8DB)),
                  _metric(
                      Icons.local_fire_department_outlined,
                      context.tr('Streak {p0}',
                          {'p0': widget.progress.dayStreak(DateTime.now())}),
                      const Color(0xFFD7B98B)),
                ]),
              ])),
        ]));
  }

  Widget _metric(IconData icon, String text, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Flexible(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: checklistMuted)))
      ]);

  Future<void> _actions(Habit h, HabitRecord? r) async {
    if (!isToday) return;
    final action = await HabitActionSheet.show(context, [
      'Edit habit',
      if (r?.plan.type == 'count' && r?.scheduled == true && r?.rest != true)
        'Set progress',
      if (r?.rest == true)
        'Cancel rest'
      else if (r?.scheduled == true && !widget.progress.wasCredited(day, h.id))
        'Rest today',
      'Remove',
    ]);
    if (!mounted) return;
    if (action == 'Edit habit') {
      compose(initial: h);
    } else if (action == 'Set progress') {
      final value = await NumericGoalSheet.show(context, r!.value,
          minimum: 0, maximum: r.plan.target, title: 'Set progress');
      if (value != null && mounted) change(h, amount: value);
    } else if (action == 'Rest today') {
      change(h, rest: true);
    } else if (action == 'Cancel rest') {
      change(h, rest: false);
    } else if (action == 'Remove') {
      final confirm = await showDialog<bool>(
          context: context,
          builder: (c) =>
              AlertDialog(title: Text(c.tr('Remove habit?')), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(c.tr('Cancel'))),
                TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(c.tr('Remove'))),
              ]));
      if (confirm == true && mounted)
        replace(h.copyWith(checklist: data(h).copy(archived: true)));
    }
  }

  Widget _habit(Habit h, int index) {
    final r = record(h);
    final editable = isToday && r?.scheduled == true && r?.rest != true;
    final status = plannerStatus(r, selected, DateTime.now());
    final label = context.tr(
        status.label,
        status.label == 'Scheduled at {p0}'
            ? {'p0': clockLabel(context, r!.plan.activityMinute!)}
            : status.arguments);
    final measured = r != null && r.plan.type != 'checkbox';
    return Material(
        color: checklistSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: r?.done == true
                    ? checklistPrimary.withValues(alpha: .3)
                    : checklistBorder)),
        child: InkWell(
            onTap: () => detail(h),
            onLongPress: isToday ? () => _actions(h, r) : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: checklistBorder.withValues(alpha: .6),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(habitIcon(h.iconKey),
                          size: 20, color: checklistPrimary)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(h.title,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.3)),
                        if (measured) ...[
                          const SizedBox(height: 5),
                          Text(
                              '${r.value} / ${r.plan.target}${r.plan.type == 'duration' ? ' ${context.tr('min')}' : r.plan.unit == 'count' ? '' : ' ${r.plan.unit}'}',
                              style: const TextStyle(
                                  fontSize: 12, color: checklistMuted)),
                          const SizedBox(height: 7),
                          LinearProgressIndicator(
                              value: (r.value / r.plan.target).clamp(0, 1),
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(2),
                              color: checklistPrimary,
                              backgroundColor: checklistBorder),
                        ],
                        if (r?.plan.activityMinute != null &&
                            status.label != 'Scheduled at {p0}') ...[
                          const SizedBox(height: 6),
                          Text(clockLabel(context, r!.plan.activityMinute!),
                              style: const TextStyle(
                                  fontSize: 12, color: checklistMuted)),
                        ],
                        const SizedBox(height: 6),
                        Text(label,
                            style: TextStyle(
                                fontSize: 12,
                                color: r?.done == true
                                    ? checklistPrimary
                                    : checklistMuted)),
                      ])),
                  const SizedBox(width: 8),
                  if (arranging && isToday)
                    ReorderableDragStartListener(
                        index: index,
                        child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.drag_handle)))
                  else if (editable && r!.plan.type == 'checkbox')
                    Checkbox(
                        key: ValueKey('habit-${h.id}'),
                        value: r.done,
                        onChanged: (_) => change(h, amount: r.done ? 0 : 1),
                        activeColor: checklistPrimary,
                        checkColor: checklistBackground,
                        side:
                            const BorderSide(color: checklistMuted, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)))
                  else if (editable && r!.plan.type == 'count')
                    IconButton.filledTonal(
                        tooltip: context.tr('Increase'),
                        key: ValueKey('increment-${h.id}'),
                        onPressed: r.done
                            ? null
                            : () => change(h, amount: r.value + 1),
                        icon: const Icon(Icons.add))
                  else if (editable && r!.plan.type == 'duration')
                    IconButton.filledTonal(
                        tooltip: context.tr('Start focus'),
                        key: ValueKey('focus-${h.id}'),
                        onPressed: widget.onStartFocus == null
                            ? () => detail(h)
                            : () => widget.onStartFocus!(h),
                        icon: const Icon(Icons.play_arrow_rounded)),
                ]))));
  }

  @override
  Widget build(BuildContext context) =>
      ChecklistSurface(child: Builder(builder: _dashboard));
  Widget _dashboard(BuildContext context) {
    final visible = widget.habits
        .where((h) =>
            (!data(h).archived ||
                !isToday && data(h).records.containsKey(day)) &&
            record(h)?.scheduled == true &&
            (filter == 'All' || data(h).category == filter))
        .toList()
      ..sort((a, b) {
        const categories = ['Morning', 'Afternoon', 'Evening', 'Custom'];
        final c = categories
            .indexOf(data(a).category)
            .compareTo(categories.indexOf(data(b).category));
        return c != 0 ? c : data(a).order.compareTo(data(b).order);
      });
    final scheduled = widget.habits
        .where((h) =>
            (!data(h).archived || !isToday) &&
            record(h)?.scheduled == true &&
            record(h)?.rest != true)
        .toList();
    final done = scheduled.where((h) => record(h)!.done).length;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ColoredBox(
        color: checklistBackground,
        child: Column(children: [
          Expanded(
              child: CustomScrollView(slivers: [
            SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverList.list(children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(context.tr('Checklist'),
                              key: const ValueKey('checklist-title'),
                              style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.8,
                                  height: 1.2)),
                          const SizedBox(height: 6),
                          Text(DateFormat.MMMMEEEEd(locale).format(selected),
                              style: const TextStyle(
                                  fontSize: 13, color: checklistMuted))
                        ])),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                        tooltip: context.tr('Calendar'),
                        onPressed: calendar,
                        style: IconButton.styleFrom(
                            side: const BorderSide(color: checklistBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            minimumSize: const Size(48, 48)),
                        icon: const Icon(Icons.calendar_today_outlined,
                            size: 20)),
                    if (widget.onOpenSettings != null)
                      IconButton(
                          tooltip: context.tr('Settings'),
                          onPressed: widget.onOpenSettings,
                          icon: const Icon(Icons.tune_rounded, size: 21))
                  ]),
                  const SizedBox(height: 22),
                  _week(locale),
                  const SizedBox(height: 18),
                  _summary(done, scheduled.length),
                  const SizedBox(height: 18),
                  if (!isToday)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                            context.tr(
                                'History is read-only. Missing records are unknown.'),
                            style: const TextStyle(
                                fontSize: 12, color: checklistMuted))),
                  if (!widget.masterEnabled &&
                      widget.habits.any((h) => h.reminderEnabled))
                    TextButton.icon(
                        key: const ValueKey('reminder-master-warning'),
                        onPressed: widget.onEnableMaster,
                        icon: const Icon(Icons.notifications_off_outlined,
                            size: 18),
                        label: Text(context.tr(
                            'Habit reminders are paused because master notifications are off.'))),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final category in [
                          'All',
                          'Morning',
                          'Afternoon',
                          'Evening',
                          'Custom'
                        ])
                          Semantics(
                              selected: filter == category,
                              child: TextButton(
                                  onPressed: () =>
                                      setState(() => filter = category),
                                  style: TextButton.styleFrom(
                                      foregroundColor: filter == category
                                          ? checklistText
                                          : checklistMuted,
                                      minimumSize: const Size(48, 48),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14),
                                      shape: const RoundedRectangleBorder()),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(context.tr(category),
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: filter == category
                                                    ? FontWeight.w700
                                                    : FontWeight.w400)),
                                        const SizedBox(height: 9),
                                        Container(
                                            height: 2,
                                            width: 18,
                                            color: filter == category
                                                ? checklistPrimary
                                                : Colors.transparent)
                                      ])))
                      ])),
                  Row(children: [
                    Expanded(
                        child: Text(context.tr('Your routine'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600))),
                    IconButton(
                        tooltip:
                            context.tr(arranging ? 'Done' : 'Reorder habits'),
                        onPressed: isToday
                            ? () => setState(() => arranging = !arranging)
                            : null,
                        icon: Icon(
                            arranging ? Icons.check_rounded : Icons.swap_vert,
                            size: 20,
                            color: checklistMuted)),
                    IconButton(
                        key: const ValueKey('manage-habits'),
                        tooltip: context.tr('Manage habits'),
                        onPressed: manageHabits,
                        icon: const Icon(Icons.edit_calendar_outlined,
                            size: 20, color: checklistMuted)),
                    IconButton(
                        tooltip: context.tr('Templates'),
                        onPressed: templates,
                        icon: const Icon(Icons.library_add_outlined,
                            size: 20, color: checklistMuted))
                  ]),
                  if (visible.isEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(children: [
                          const Icon(Icons.spa_outlined,
                              size: 36, color: checklistPrimary),
                          const SizedBox(height: 14),
                          Text(
                              context.tr(!isToday
                                  ? 'No scheduled record'
                                  : widget.habits.any((h) => !data(h).archived)
                                      ? 'No habits scheduled'
                                      : 'Plant your first daily habit 🌱'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: checklistMuted))
                        ])),
                ])),
            SliverReorderableList(
                itemCount: visible.length,
                // ignore: deprecated_member_use
                onReorder: (oldIndex, newIndex) {
                  if (!isToday || !arranging) return;
                  if (newIndex > oldIndex) newIndex--;
                  if (data(visible[oldIndex]).category !=
                      data(visible[newIndex]).category) return;
                  final moved = visible.removeAt(oldIndex);
                  visible.insert(newIndex, moved);
                  final updates = {
                    for (var i = 0; i < visible.length; i++)
                      visible[i].id: visible[i]
                          .copyWith(checklist: data(visible[i]).copy(order: i))
                  };
                  widget.onChanged(
                      [for (final h in widget.habits) updates[h.id] ?? h]);
                },
                itemBuilder: (context, index) {
                  final h = visible[index];
                  final group = index == 0 ||
                      data(visible[index - 1]).category != data(h).category;
                  return Padding(
                      key: ValueKey(h.id),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (group)
                              Padding(
                                  padding: const EdgeInsets.only(
                                      top: 8, bottom: 10, left: 2),
                                  child: Text(context.tr(data(h).category),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: checklistMuted,
                                          letterSpacing: .4))),
                            _habit(h, index)
                          ]));
                }),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: () => compose(),
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(context.tr('Add a daily habit'))))),
        ]));
  }
}
