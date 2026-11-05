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
      this.onOpenSettings});
  final VoidCallback? onOpenSettings;
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
    final next = r.change(value: amount?.clamp(0, 100000), rest: rest);
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

  Widget _menu(Habit h, HabitRecord? r) => PopupMenuButton<String>(
      tooltip: context.tr('Edit habit'),
      icon: const Icon(Icons.more_horiz, size: 20, color: checklistMuted),
      onSelected: (action) async {
        if (action == 'Edit habit') {
          compose(initial: h);
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
                        child: Text(c.tr('Remove')))
                  ]));
          if (confirm == true && mounted)
            replace(h.copyWith(checklist: data(h).copy(archived: true)));
        }
      },
      itemBuilder: (context) => [
            for (final action in [
              'Edit habit',
              if (r?.rest == true)
                'Cancel rest'
              else if (r?.scheduled == true &&
                  !widget.progress.wasCredited(day, h.id))
                'Rest today',
              'Remove'
            ])
              PopupMenuItem(value: action, child: Text(context.tr(action)))
          ]);

  Widget _habit(Habit h, int index) {
    final r = record(h);
    final measured = r != null && r.plan.type != 'checkbox';
    final editable = isToday && r?.scheduled == true && r?.rest != true;
    final status = r == null
        ? (widget.progress.wasCredited(day, h.id)
            ? 'Water credited; target unknown'
            : 'Unknown')
        : r.status == 'Missed' && isToday
            ? 'Not completed'
            : r.status;
    return Container(
        decoration: BoxDecoration(
            color: checklistSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: r?.done == true
                    ? checklistPrimary.withValues(alpha: .25)
                    : checklistBorder.withValues(alpha: .45))),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: checklistBorder.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(habitIcon(h.iconKey),
                    size: 20, color: checklistPrimary)),
            const SizedBox(width: 12),
            Expanded(
                child: InkWell(
                    onTap: () => detail(h),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h.title,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                      color: r?.done == true
                                          ? checklistMuted
                                          : checklistText)),
                              const SizedBox(height: 3),
                              Text(
                                  measured && r.scheduled && !r.rest
                                      ? '${r.value} / ${r.plan.target} ${r.plan.type == 'duration' ? context.tr('minutes') : r.plan.unit}'
                                      : context.tr(status),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: checklistMuted,
                                      height: 1.4)),
                            ])))),
            if (arranging && isToday)
              ReorderableDragStartListener(
                  index: index,
                  child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.drag_handle, color: checklistMuted)))
            else if (!measured && editable)
              Semantics(
                  label: context.tr(r!.done ? 'Done' : 'Complete'),
                  child: Checkbox(
                      key: ValueKey('habit-${h.id}'),
                      value: r.done,
                      onChanged: (_) => change(h, amount: r.done ? 0 : 1),
                      activeColor: checklistPrimary,
                      checkColor: checklistBackground,
                      side: const BorderSide(color: checklistMuted, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      materialTapTargetSize: MaterialTapTargetSize.padded))
            else if (isToday)
              _menu(h, r),
            if (!measured && editable && !arranging) _menu(h, r),
          ]),
          if (measured && r.scheduled && !r.rest)
            Padding(
                padding: const EdgeInsets.only(
                    left: 50, right: 6, top: 4, bottom: 2),
                child: Column(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                          value: (r.value / r.plan.target).clamp(0, 1),
                          minHeight: 3,
                          color: checklistPrimary,
                          backgroundColor: checklistBorder)),
                  if (editable && !arranging)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                            width: double.infinity,
                            child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  IconButton(
                                      tooltip: context.tr('Decrease'),
                                      onPressed: r.value == 0
                                          ? null
                                          : () =>
                                              change(h, amount: r.value - 1),
                                      icon: const Icon(Icons.remove, size: 18),
                                      constraints: const BoxConstraints(
                                          minWidth: 48, minHeight: 48)),
                                  if (r.plan.type == 'duration')
                                    TextButton(
                                        onPressed: () =>
                                            change(h, amount: r.value + 5),
                                        child: const Text('+5')),
                                  OutlinedButton(
                                      onPressed: () =>
                                          change(h, amount: r.value + 1),
                                      style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(56, 40),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      child: const Text('+1')),
                                ]))),
                ])),
        ]));
  }

  @override
  Widget build(BuildContext context) =>
      ChecklistSurface(child: Builder(builder: _dashboard));
  Widget _dashboard(BuildContext context) {
    final visible = widget.habits
        .where((h) =>
            (!data(h).archived ||
                !isToday && data(h).records.containsKey(day)) &&
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
                          Text(context.tr('Plant your first daily habit 🌱'),
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
  late final TextEditingController title, target, unit;
  late String icon, category, type;
  late Set<int> days;
  late bool reminder;
  late TimeOfDay time;
  int step = 0;
  String query = '';
  String iconCategory = 'All';
  final iconScroll = ScrollController();
  final form = GlobalKey<FormState>();
  late bool masterActive;
  @override
  void initState() {
    super.initState();
    masterActive = widget.masterEnabled;
    final h = widget.initial;
    final d = h?.checklist;
    final p = d?.pending ?? d?.plan ?? const HabitPlan();
    title = TextEditingController(text: h?.title ?? '');
    target = TextEditingController(text: '${p.target}');
    unit = TextEditingController(text: p.unit);
    icon = h?.iconKey ?? 'leaf';
    category = d?.category ?? 'Morning';
    type = p.type;
    days = p.weekdays.toSet();
    reminder = h?.reminderEnabled ?? false;
    time =
        TimeOfDay(hour: h?.reminderHour ?? 20, minute: h?.reminderMinute ?? 0);
  }

  @override
  void dispose() {
    title.dispose();
    target.dispose();
    unit.dispose();
    iconScroll.dispose();
    super.dispose();
  }

  void save() {
    if (!form.currentState!.validate() || days.isEmpty) return;
    final now = DateTime.now();
    final p = HabitPlan(
        type: type,
        target: type == 'checkbox' ? 1 : int.parse(target.text),
        unit: type == 'count' ? unit.text.trim() : '',
        weekdays: days.toList()..sort());
    final old = widget.initial;
    final d = (old?.checklist ?? ChecklistData(start: checklistDay(now)))
        .advance(now);
    final updated = widget.creating
        ? d.copy(plan: p, category: category)
        : d.edit(p, now).copy(category: category);
    Navigator.pop(
        context,
        Habit(
            id: widget.creating ? const Uuid().v4() : old!.id,
            title: title.text.trim(),
            iconKey: icon,
            completed: old?.completed ?? false,
            reminderEnabled: reminder,
            reminderHour: time.hour,
            reminderMinute: time.minute,
            checklist: updated));
  }

  @override
  Widget build(BuildContext context) =>
      ChecklistSurface(child: Builder(builder: _editor));
  Widget _editor(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(context
              .tr(widget.creating ? 'Plant a new habit' : 'Edit habit'))),
      body: SafeArea(
          child: Form(
              key: form,
              child: Column(children: [
                Expanded(
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                  Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(children: [
                        for (var i = 0; i < 2; i++)
                          Expanded(
                              child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                            height: 3,
                                            decoration: BoxDecoration(
                                                color: i <= step
                                                    ? checklistPrimary
                                                    : checklistBorder,
                                                borderRadius:
                                                    BorderRadius.circular(2))),
                                        const SizedBox(height: 10),
                                        Text(
                                            '${i + 1}  ${context.tr(i == 0 ? 'Habit name' : 'Goal type')}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: i == step
                                                    ? checklistText
                                                    : checklistMuted))
                                      ])))
                      ])),
                  if (step == 0) ...[
                    TextFormField(
                        controller: title,
                        maxLength: 300,
                        decoration: InputDecoration(
                            labelText: context.tr('Habit name')),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? context.tr('Required')
                            : null),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: category,
                        decoration:
                            InputDecoration(labelText: context.tr('Category')),
                        items: [
                          for (final c in [
                            'Morning',
                            'Afternoon',
                            'Evening',
                            'Custom'
                          ])
                            DropdownMenuItem(
                                value: c, child: Text(context.tr(c)))
                        ],
                        onChanged: (v) => setState(() => category = v!)),
                    const SizedBox(height: 24),
                    Text(context.tr('Pick an icon'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: InputDecoration(
                            labelText: context.tr('Search icons')),
                        onChanged: (v) =>
                            setState(() => query = v.toLowerCase())),
                    Wrap(spacing: 8, children: [
                      for (final c in [
                        'All',
                        ...habitIcons.map((e) => e.category).toSet()
                      ])
                        ChoiceChip(
                            showCheckmark: false,
                            label:
                                Text(context.tr(c == 'Legacy' ? 'Classic' : c)),
                            selected: iconCategory == c,
                            onSelected: (_) => setState(() => iconCategory = c))
                    ]),
                    ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: Scrollbar(
                            controller: iconScroll,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                                controller: iconScroll,
                                child:
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                  for (final i in habitIcons.where((i) =>
                                      (iconCategory == 'All' || i.category == iconCategory) &&
                                      (context.tr(i.label).toLowerCase().contains(query) ||
                                          i.key.contains(query))))
                                    Semantics(
                                        selected: icon == i.key,
                                        child: IconButton.filledTonal(
                                            tooltip: context.tr(i.label),
                                            isSelected: icon == i.key,
                                            onPressed: () =>
                                                setState(() => icon = i.key),
                                            icon: Icon(i.icon),
                                            style: IconButton.styleFrom(
                                                minimumSize: const Size(48, 48),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                                side: icon == i.key
                                                    ? const BorderSide(color: checklistPrimary, width: 2)
                                                    : null)))
                                ]))))
                  ] else ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: type,
                        decoration:
                            InputDecoration(labelText: context.tr('Goal type')),
                        items: [
                          for (final t in ['checkbox', 'count', 'duration'])
                            DropdownMenuItem(
                                value: t,
                                child: Text(context.tr(t == 'checkbox'
                                    ? 'Check-in'
                                    : t == 'count'
                                        ? 'Count'
                                        : 'Duration')))
                        ],
                        onChanged: (v) => setState(() => type = v!)),
                    if (type != 'checkbox') const SizedBox(height: 16),
                    if (type != 'checkbox')
                      TextFormField(
                          controller: target,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: context.tr(
                                  type == 'duration' ? 'minutes' : 'Target')),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return n == null || n < 1 || n > 100000
                                ? context.tr('Enter 1–100000')
                                : null;
                          }),
                    if (type == 'count') const SizedBox(height: 16),
                    if (type == 'count')
                      TextFormField(
                          controller: unit,
                          maxLength: 40,
                          decoration:
                              InputDecoration(labelText: context.tr('Unit')),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? context.tr('Required')
                              : null),
                    const SizedBox(height: 24),
                    Text(context.tr('Schedule'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      for (final preset in [
                        'Every day',
                        'Weekdays',
                        'Weekends'
                      ])
                        ActionChip(
                            label: Text(context.tr(preset)),
                            onPressed: () =>
                                setState(() => days = preset == 'Every day'
                                    ? {1, 2, 3, 4, 5, 6, 7}
                                    : preset == 'Weekdays'
                                        ? {1, 2, 3, 4, 5}
                                        : {6, 7}))
                    ]),
                    const SizedBox(height: 8),
                    LayoutBuilder(builder: (context, constraints) {
                      final minimum =
                          MediaQuery.textScalerOf(context).scale(1) > 1.4
                              ? 476.0
                              : 336.0;
                      return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                              width: constraints.maxWidth < minimum
                                  ? minimum
                                  : constraints.maxWidth,
                              child: Row(children: [
                                for (var i = 1; i <= 7; i++)
                                  Expanded(
                                      child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 2),
                                          child: Semantics(
                                              selected: days.contains(i),
                                              child: TextButton(
                                                style: TextButton.styleFrom(
                                                    minimumSize:
                                                        const Size(44, 48),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 10),
                                                    backgroundColor:
                                                        days.contains(i)
                                                            ? checklistPrimary
                                                            : checklistSurface,
                                                    foregroundColor: days
                                                            .contains(i)
                                                        ? checklistBackground
                                                        : checklistMuted,
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10))),
                                                onPressed: () => setState(() {
                                                  if (!days.contains(i)) {
                                                    days.add(i);
                                                  } else if (days.length > 1) {
                                                    days.remove(i);
                                                  }
                                                }),
                                                child: Text(
                                                    DateFormat.E(Localizations
                                                                .localeOf(
                                                                    context)
                                                            .toLanguageTag())
                                                        .format(DateTime(
                                                            2026, 11, 1 + i)),
                                                    style: const TextStyle(
                                                        fontSize: 12)),
                                              )))),
                              ])));
                    }),
                    const SizedBox(height: 24),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.tr('Remind on scheduled days')),
                        value: reminder,
                        onChanged: (v) => setState(() => reminder = v)),
                    if (reminder)
                      ListTile(
                          title: Text(context.tr('Reminder time')),
                          subtitle: Text(time.format(context)),
                          onTap: () async {
                            final next = await showTimePicker(
                                context: context, initialTime: time);
                            if (next != null && mounted)
                              setState(() => time = next);
                          }),
                    if (reminder && !masterActive)
                      Text(context.tr(
                          'Master notifications are OFF — reminders will be paused')),
                    if (reminder && !masterActive)
                      TextButton.icon(
                          onPressed: () async {
                            final enabled = await widget.onEnableMaster();
                            if (mounted) setState(() => masterActive = enabled);
                          },
                          icon: const Icon(Icons.notifications_active_outlined),
                          label:
                              Text(context.tr('Enable master notifications'))),
                    if (!widget.creating)
                      Text(context
                          .tr('Target and schedule changes start tomorrow.')),
                  ]
                ])),
                Padding(
                    padding: const EdgeInsets.all(16),
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
                              child: Text(context
                                  .tr(step == 0 ? 'Continue' : 'Save habit'))))
                    ]))
              ]))));
}
