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
      required this.onEnableMaster});
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
    var habit = initial;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (route) => StatefulBuilder(builder: (route, update) {
                  final d = data(habit);
                  final r = d.today(DateTime.now());
                  void increment(int amount) {
                    if (!r.scheduled || r.rest || !isToday) return;
                    final next =
                        r.change(value: (r.value + amount).clamp(0, 100000));
                    habit = habit.copyWith(
                        completed: next.done,
                        checklist: d.record(DateTime.now(), next));
                    replace(habit);
                    update(() {});
                  }

                  return Scaffold(
                      appBar: AppBar(title: Text(habit.title), actions: [
                        if (isToday)
                          IconButton(
                              tooltip: route.tr('Edit habit'),
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () {
                                Navigator.pop(route);
                                compose(initial: habit);
                              })
                      ]),
                      body: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                                '${r.value} / ${r.plan.target} ${r.plan.type == 'duration' ? route.tr('minutes') : r.plan.unit}',
                                style: Theme.of(route).textTheme.headlineSmall),
                            Text(d
                                .planOn(checklistDay(DateTime.now()))
                                .weekdays
                                .map((i) => DateFormat.E(
                                        Localizations.localeOf(route)
                                            .toLanguageTag())
                                    .format(DateTime(2026, 11, 1 + i)))
                                .join(' · ')),
                            if (habit.reminderEnabled)
                              Text(TimeOfDay(
                                      hour: habit.reminderHour,
                                      minute: habit.reminderMinute)
                                  .format(route)),
                            if (isToday && r.scheduled && !r.rest)
                              Wrap(spacing: 8, children: [
                                IconButton(
                                    tooltip: route.tr('Decrease'),
                                    onPressed: () => increment(-1),
                                    icon: const Icon(Icons.remove)),
                                FilledButton(
                                    onPressed: () => increment(1),
                                    child: const Text('+1')),
                                if (r.plan.type == 'duration') ...[
                                  FilledButton(
                                      onPressed: () => increment(5),
                                      child: const Text('+5')),
                                  FilledButton(
                                      onPressed: () => increment(10),
                                      child: const Text('+10'))
                                ],
                                FilledButton(
                                    onPressed: () =>
                                        increment(r.plan.target - r.value),
                                    child: Text(route.tr('Complete'))),
                              ]),
                            Text(route.tr('Scheduled habit streak: {p0}',
                                {'p0': d.streak(DateTime.now())})),
                            Wrap(spacing: 12, children: [
                              for (final milestone in [7, 30, 100])
                                Chip(
                                    avatar: Icon(
                                        d.streak(DateTime.now(), best: true) >=
                                                milestone
                                            ? Icons.emoji_events
                                            : Icons.lock_outline,
                                        color: d.streak(DateTime.now(),
                                                    best: true) >=
                                                milestone
                                            ? Colors.amber
                                            : Colors.grey),
                                    label: Text(route.tr(
                                        '{p0} completions', {'p0': milestone})))
                            ]),
                            for (final key
                                in (d.records.keys.toList()..sort()).reversed)
                              ListTile(
                                  title: Text(key),
                                  subtitle:
                                      Text(route.tr(d.records[key]!.status)),
                                  trailing: Text(
                                      '${d.records[key]!.value}/${d.records[key]!.plan.target}')),
                          ]));
                })));
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
        builder: (context) => SafeArea(
                child: ListView(shrinkWrap: true, children: [
              for (var i = 0; i < names.length; i++)
                ListTile(
                    leading: Icon(habitIcon(icons[i])),
                    title: Text(context.tr(names[i])),
                    subtitle: Text(context.tr('Preview and customize')),
                    onTap: () => Navigator.pop(context, i))
            ])));
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
                builder: (route, update) => Scaffold(
                    appBar: AppBar(title: Text(route.tr(names[choice]))),
                    body:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      Text(route.tr('Preview and customize')),
                      for (var i = 0; i < drafts.length; i++)
                        ListTile(
                            title: Text(drafts[i].title),
                            subtitle: Text(
                                '${drafts[i].checklist!.plan.target} ${route.tr('minutes')}'),
                            trailing: IconButton(
                                tooltip: route.tr('Edit habit'),
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  final edited = await Navigator.push<Habit>(
                                      route,
                                      MaterialPageRoute(
                                          builder: (_) => HabitEditor(
                                              initial: drafts[i],
                                              creating: true,
                                              masterEnabled:
                                                  widget.masterEnabled,
                                              onEnableMaster:
                                                  widget.onEnableMaster)));
                                  if (edited != null && route.mounted)
                                    update(() => drafts[i] = edited);
                                })),
                      FilledButton(
                          onPressed: () => Navigator.pop(route, true),
                          child: Text(route.tr('Add routine'))),
                    ])))));
    if (accepted == true && mounted)
      widget.onChanged([...widget.habits, ...drafts]);
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.habits
        .where((h) =>
            (!data(h).archived ||
                !isToday && data(h).records.containsKey(day)) &&
            (filter == 'All' || data(h).category == filter))
        .toList()
      ..sort((a, b) {
        const categories = ['Morning', 'Afternoon', 'Evening', 'Custom'];
        final category = categories
            .indexOf(data(a).category)
            .compareTo(categories.indexOf(data(b).category));
        return category != 0
            ? category
            : data(a).order.compareTo(data(b).order);
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
        color: const Color(0xFF081B1E),
        child: CustomScrollView(slivers: [
          SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(children: [
                Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(context.tr('Today’s Checklist'),
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text(DateFormat.yMMMd(locale).format(selected))
                      ])),
                  IconButton(
                      tooltip: context.tr('Calendar'),
                      onPressed: calendar,
                      icon: const Icon(Icons.calendar_month))
                ]),
                const SizedBox(height: 12),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(children: [
                      for (var i = 6; i >= 0; i--)
                        Builder(builder: (context) {
                          final now = DateTime.now();
                          final date =
                              DateTime(now.year, now.month, now.day - i);
                          return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                  avatar: Icon(
                                      historyStatus(widget.habits,
                                                  checklistDay(date)) ==
                                              'Done'
                                          ? Icons.check_circle
                                          : historyStatus(widget.habits,
                                                      checklistDay(date)) ==
                                                  'Rest'
                                              ? Icons.pause_circle
                                              : Icons.circle_outlined,
                                      size: 16),
                                  label: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(DateFormat.E(locale).format(date)),
                                        Text('${date.day}')
                                      ]),
                                  selected: checklistDay(date) == day,
                                  onSelected: (_) =>
                                      setState(() => selected = date)));
                        })
                    ])),
                const SizedBox(height: 12),
                Card(
                    color: const Color(0xFF123631),
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                  value: scheduled.isEmpty
                                      ? 0
                                      : done / scheduled.length,
                                  semanticsLabel: context.tr('{p0}/{p1} habits',
                                      {'p0': done, 'p1': scheduled.length}))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    scheduled.isEmpty
                                        ? context.tr('No habits scheduled')
                                        : context.tr('{p0}/{p1} habits', {
                                            'p0': done,
                                            'p1': scheduled.length
                                          }),
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                    value: scheduled.isEmpty
                                        ? 0
                                        : done / scheduled.length),
                                const SizedBox(height: 12),
                                Text(context
                                    .tr('{p0} water · Global streak {p1}', {
                                  'p0': widget.progress.earnedOn(day),
                                  'p1':
                                      widget.progress.dayStreak(DateTime.now())
                                })),
                              ])),
                          if (MediaQuery.sizeOf(context).width >= 360 &&
                              MediaQuery.textScalerOf(context).scale(1) <= 1.3)
                            const Padding(
                                padding: EdgeInsets.only(left: 12),
                                child: ExcludeSemantics(
                                    child: IgnorePointer(
                                        child: Image(
                                            image: AssetImage(
                                                'assets/images/checklist/sprout_reward.png'),
                                            width: 64,
                                            height: 64,
                                            fit: BoxFit.contain)))),
                        ]))),
                if (!isToday)
                  Text(context.tr(
                      'History is read-only. Missing records are unknown.')),
                if (!widget.masterEnabled &&
                    widget.habits.any((h) => h.reminderEnabled))
                  TextButton.icon(
                      key: const ValueKey('reminder-master-warning'),
                      onPressed: widget.onEnableMaster,
                      icon: const Icon(Icons.notifications_off_outlined),
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
                        Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                                label: Text(context.tr(category)),
                                selected: filter == category,
                                onSelected: (_) =>
                                    setState(() => filter = category)))
                    ])),
                if (visible.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(24),
                      child:
                          Text(context.tr('Plant your first daily habit 🌱'))),
              ])),
          SliverReorderableList(
              itemCount: visible.length,
              // ignore: deprecated_member_use
              onReorder: (oldIndex, newIndex) {
                if (!isToday) return;
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
                final r = record(h);
                return Padding(
                    key: ValueKey(h.id),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Card(
                        color: const Color(0xFF123631),
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(habitIcon(h.iconKey),
                                        color: const Color(0xFF96E4B2)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: InkWell(
                                            onTap: () => detail(h),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(h.title,
                                                      style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  Text(context
                                                      .tr(data(h).category))
                                                ]))),
                                    if (isToday)
                                      PopupMenuButton<String>(
                                          onSelected: (action) async {
                                            if (action == 'Edit habit') {
                                              compose(initial: h);
                                            } else if (action == 'Rest today') {
                                              change(h, rest: true);
                                            } else if (action ==
                                                'Cancel rest') {
                                              change(h, rest: false);
                                            } else if (action == 'Remove') {
                                              final confirm = await showDialog<
                                                      bool>(
                                                  context: context,
                                                  builder: (c) => AlertDialog(
                                                          title: Text(c.tr(
                                                              'Remove habit?')),
                                                          actions: [
                                                            TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        c,
                                                                        false),
                                                                child: Text(c.tr(
                                                                    'Cancel'))),
                                                            TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        c,
                                                                        true),
                                                                child: Text(c.tr(
                                                                    'Remove')))
                                                          ]));
                                              if (confirm == true && mounted)
                                                replace(h.copyWith(
                                                    checklist: data(h)
                                                        .copy(archived: true)));
                                            }
                                          },
                                          itemBuilder: (context) => [
                                                for (final action in [
                                                  'Edit habit',
                                                  if (r?.rest == true)
                                                    'Cancel rest'
                                                  else if (r?.scheduled ==
                                                          true &&
                                                      !widget.progress
                                                          .wasCredited(
                                                              day, h.id))
                                                    'Rest today',
                                                  'Remove'
                                                ])
                                                  PopupMenuItem(
                                                      value: action,
                                                      child: Text(
                                                          context.tr(action)))
                                              ]),
                                    if (isToday)
                                      ReorderableDragStartListener(
                                          index: index,
                                          child: const SizedBox(
                                              width: 48,
                                              height: 48,
                                              child: Icon(Icons.drag_handle))),
                                  ]),
                                  if (r == null)
                                    Text(context.tr(
                                        widget.progress.wasCredited(day, h.id)
                                            ? 'Water credited; target unknown'
                                            : 'Unknown'))
                                  else ...[
                                    Text(context.tr(
                                        r.status == 'Missed' && isToday
                                            ? 'Not completed'
                                            : r.status)),
                                    if (r.scheduled && !r.rest) ...[
                                      if (r.plan.type != 'checkbox') ...[
                                        Text(
                                            '${r.value} / ${r.plan.target} ${r.plan.type == 'duration' ? context.tr('minutes') : r.plan.unit}'),
                                        LinearProgressIndicator(
                                            value: (r.value / r.plan.target)
                                                .clamp(0, 1))
                                      ],
                                      if (isToday)
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            if (r.plan.type == 'checkbox')
                                              FilledButton.tonalIcon(
                                                  key:
                                                      ValueKey('habit-${h.id}'),
                                                  onPressed: () => change(h,
                                                      amount: r.done ? 0 : 1),
                                                  icon: Icon(r.done
                                                      ? Icons.check_circle
                                                      : Icons.circle_outlined),
                                                  label: Text(context.tr(r.done
                                                      ? 'Done'
                                                      : 'Complete')))
                                            else ...[
                                              IconButton(
                                                  tooltip:
                                                      context.tr('Decrease'),
                                                  onPressed: () => change(h,
                                                      amount: r.value - 1),
                                                  icon:
                                                      const Icon(Icons.remove)),
                                              FilledButton.tonal(
                                                  onPressed: () => change(h,
                                                      amount: r.value + 1),
                                                  child: const Text('+1')),
                                              if (r.plan.type == 'duration')
                                                FilledButton.tonal(
                                                    onPressed: () => change(h,
                                                        amount: r.value + 5),
                                                    child: const Text('+5'))
                                            ]
                                          ],
                                        ),
                                    ],
                                  ],
                                ]))));
              }),
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverToBoxAdapter(
                  child: Wrap(spacing: 12, runSpacing: 8, children: [
                FilledButton.icon(
                    onPressed: () => compose(),
                    icon: const Icon(Icons.add),
                    label: Text(context.tr('Add a daily habit'))),
                OutlinedButton.icon(
                    onPressed: templates,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(context.tr('Templates')))
              ]))),
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
  Widget build(BuildContext context) => Scaffold(
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
                  Text('${step + 1}/2'),
                  if (step == 0) ...[
                    TextFormField(
                        controller: title,
                        maxLength: 300,
                        decoration: InputDecoration(
                            labelText: context.tr('Habit name')),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? context.tr('Required')
                            : null),
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
                    Text(context.tr('Pick an icon')),
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
                            label: Text(context.tr(c)),
                            selected: iconCategory == c,
                            onSelected: (_) => setState(() => iconCategory = c))
                    ]),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final i in habitIcons.where((i) =>
                          (iconCategory == 'All' ||
                              i.category == iconCategory) &&
                          (context.tr(i.label).toLowerCase().contains(query) ||
                              i.key.contains(query))))
                        Semantics(
                            selected: icon == i.key,
                            child: IconButton.filledTonal(
                                tooltip: context.tr(i.label),
                                isSelected: icon == i.key,
                                onPressed: () => setState(() => icon = i.key),
                                icon: Icon(i.icon),
                                style: IconButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    side: icon == i.key
                                        ? const BorderSide(
                                            color: Colors.lightGreen, width: 2)
                                        : null)))
                    ])
                  ] else ...[
                    DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: type,
                        decoration:
                            InputDecoration(labelText: context.tr('Goal type')),
                        items: [
                          for (final t in ['checkbox', 'count', 'duration'])
                            DropdownMenuItem(
                                value: t, child: Text(context.tr(t)))
                        ],
                        onChanged: (v) => setState(() => type = v!)),
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
                    if (type == 'count')
                      TextFormField(
                          controller: unit,
                          maxLength: 40,
                          decoration:
                              InputDecoration(labelText: context.tr('Unit')),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? context.tr('Required')
                              : null),
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
                    Wrap(spacing: 6, children: [
                      for (var i = 1; i <= 7; i++)
                        FilterChip(
                            label: Text(DateFormat.E(
                                    Localizations.localeOf(context)
                                        .toLanguageTag())
                                .format(DateTime(2026, 11, 2 + i - 1))),
                            selected: days.contains(i),
                            onSelected: (v) => setState(() {
                                  if (v)
                                    days.add(i);
                                  else if (days.length > 1) days.remove(i);
                                }))
                    ]),
                    SwitchListTile(
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
