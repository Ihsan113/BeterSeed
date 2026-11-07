import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/habit.dart';
import '../l10n/app_localizations.dart';
import 'checklist_data.dart';
import 'checklist_pickers.dart';
import 'checklist_style.dart';
import 'habit_editor.dart';
import 'habit_icons.dart';
import 'habit_library.dart';

class HabitManagerPage extends StatefulWidget {
  const HabitManagerPage(
      {super.key,
      required this.habits,
      required this.onChanged,
      required this.masterEnabled,
      required this.onEnableMaster,
      required this.scope});
  final ValueListenable<List<Habit>> habits;
  final Future<void> Function(List<Habit>) onChanged;
  final bool Function() masterEnabled;
  final Future<bool> Function() onEnableMaster;
  final String Function() scope;
  @override
  State<HabitManagerPage> createState() => _HabitManagerPageState();
}

class _HabitManagerPageState extends State<HabitManagerPage> {
  final search = TextEditingController();
  late final String owner;
  LibraryStatus status = LibraryStatus.all;
  LibrarySort sort = LibrarySort.manual;
  String? category;
  int? weekday;
  bool selecting = false, busy = false, reordering = false;
  final selected = <String>{};
  List<String> draftOrder = [];
  DateTime get now => DateTime.now();
  bool get sameScope => owner == widget.scope();
  List<Habit> get items => widget.habits.value;
  List<Habit> get visible => libraryHabits(items, now,
      query: search.text,
      category: category,
      weekday: weekday,
      status: status,
      sort: sort);
  @override
  void initState() {
    super.initState();
    owner = widget.scope();
    widget.habits.addListener(refresh);
  }

  void refresh() {
    if (!mounted) return;
    setState(() {
      final shown = visible.map((h) => h.id).toSet();
      selected.removeWhere((id) => !shown.contains(id));
      if (!sameScope ||
          (reordering &&
              !setEquals(draftOrder.toSet(), items.map((h) => h.id).toSet()))) {
        selected.clear();
        reordering = false;
      }
    });
  }

  @override
  void dispose() {
    widget.habits.removeListener(refresh);
    search.dispose();
    super.dispose();
  }

  void notice(String message) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr(message))));
  }

  void filter(VoidCallback change) => setState(() {
        change();
        selected.clear();
        selecting = false;
      });

  Future<bool> save(List<Habit> next) async {
    if (busy || !sameScope) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => busy = true);
    try {
      await widget.onChanged(next);
      if (!mounted || !sameScope) return false;
      setState(() {
        selected.clear();
        selecting = false;
        reordering = false;
      });
      notice('Changes saved');
      return true;
    } catch (_) {
      notice('Changes could not be saved. Please try again.');
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(Habit original) async {
    if (busy || !sameScope) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    final result = await Navigator.push<Habit>(
        context,
        MaterialPageRoute(
            builder: (_) => HabitEditor(
                initial:
                    original.copyWith(checklist: libraryData(original, now)),
                creating: false,
                masterEnabled: widget.masterEnabled(),
                onEnableMaster: widget.onEnableMaster)));
    if (!mounted || result == null || !sameScope) return;
    final current = items.where((h) => h.id == original.id).firstOrNull;
    if (current == null ||
        jsonEncode(current.toJson()) != jsonEncode(original.toJson())) {
      notice('This habit changed. Reopen it before editing.');
      return;
    }
    await save([for (final h in items) h.id == result.id ? result : h]);
  }

  Future<bool> confirm(String action, Set<String> ids) async {
    final chosen = items.where((h) => ids.contains(h.id)).toList();
    final accepted = await plannerSheet<bool>(
        context,
        action,
        (context) =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(context
                  .tr('Apply to {p0} selected habits?', {'p0': chosen.length})),
              const SizedBox(height: 12),
              for (final h in chosen.take(5))
                Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(h.title)),
              if (chosen.length > 5)
                Text(context.tr('And {p0} more', {'p0': chosen.length - 5})),
              const SizedBox(height: 12),
              Text(context.tr('Recorded progress and earned water are kept.'),
                  style: const TextStyle(color: checklistMuted, fontSize: 12)),
              pickerActions(context, () => Navigator.pop(context, true),
                  saveLabel: 'Apply'),
            ]));
    return accepted == true && mounted && sameScope;
  }

  Future<void> action(String action, Set<String> ids) async {
    if (busy || !sameScope || ids.isEmpty) return;
    // Re-read latest values after every dialog; never write a captured whole list.
    String? newCategory;
    Set<int>? days;
    if (action == 'Category') {
      newCategory = await HabitCategoryPicker.show(context, 'Morning');
      if (newCategory == null) return;
    } else if (action == 'Activity days') {
      days = await ScheduleDayPicker.show(context, {1, 2, 3, 4, 5, 6, 7});
      if (days == null) return;
    }
    if (!mounted || !await confirm(action, ids) || !sameScope) return;
    if (!items.map((h) => h.id).toSet().containsAll(ids)) {
      notice('Habits changed. Review your selection and try again.');
      return;
    }
    final date = now;
    await save([
      for (final h in items)
        if (!ids.contains(h.id))
          h
        else
          switch (action) {
            'Archive habits' => archiveLibraryHabit(h, date, true),
            'Restore habits' => archiveLibraryHabit(h, date, false),
            'Turn off reminders' => h.copyWith(reminderEnabled: false),
            'Category' => h.copyWith(
                checklist: libraryData(h, date).copy(category: newCategory!)),
            'Activity days' => scheduleLibraryHabit(h, days!, date),
            _ => h,
          }
    ]);
  }

  Future<void> bulkActions() async {
    if (busy || !sameScope) return;
    final ids = {...selected};
    final chosen = items.where((h) => ids.contains(h.id)).toList();
    final result = await HabitActionSheet.show(context, [
      'Category',
      'Activity days',
      'Turn off reminders',
      if (chosen.any((h) => !libraryData(h, now).archived)) 'Archive habits',
      if (chosen.any((h) => libraryData(h, now).archived)) 'Restore habits',
    ]);
    if (result != null && mounted) await action(result, ids);
  }

  Future<void> rowActions(Habit h) async {
    if (busy || !sameScope) return;
    final result = await HabitActionSheet.show(context, [
      'Edit habit',
      libraryData(h, now).archived ? 'Restore habits' : 'Archive habits'
    ]);
    if (!mounted || result == null) return;
    if (result == 'Edit habit') {
      await edit(h);
    } else {
      await action(result, {h.id});
    }
  }

  Future<void> filters() async {
    if (busy || !sameScope) return;
    var nextStatus = status;
    var nextDay = weekday;
    var nextCategory = category;
    final accepted = await plannerSheet<bool>(
        context,
        'Filter habits',
        (context) => StatefulBuilder(
            builder: (context, update) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.tr('Status')),
                      Wrap(spacing: 8, children: [
                        for (final s in LibraryStatus.values)
                          ChoiceChip(
                              label: Text(context.tr(statusLabel(s))),
                              selected: nextStatus == s,
                              onSelected: (_) => update(() => nextStatus = s))
                      ]),
                      const SizedBox(height: 16),
                      Text(context.tr('Category')),
                      Wrap(spacing: 8, children: [
                        for (final c in <String?>[
                          null,
                          'Morning',
                          'Afternoon',
                          'Evening',
                          'Custom'
                        ])
                          ChoiceChip(
                              label: Text(context.tr(c ?? 'All')),
                              selected: nextCategory == c,
                              onSelected: (_) => update(() => nextCategory = c))
                      ]),
                      const SizedBox(height: 16),
                      Text(context.tr('Activity days')),
                      Wrap(spacing: 8, children: [
                        for (final day in <int?>[null, 1, 2, 3, 4, 5, 6, 7])
                          ChoiceChip(
                              label: Text(day == null
                                  ? context.tr('Any day')
                                  : weekdayLabel(context, day)),
                              selected: nextDay == day,
                              onSelected: (_) => update(() => nextDay = day))
                      ]),
                      pickerActions(
                          context, () => Navigator.pop(context, true)),
                    ])));
    if (accepted == true && mounted)
      filter(() {
        status = nextStatus;
        category = nextCategory;
        weekday = nextDay;
      });
  }

  Future<void> sorting() async {
    if (busy || !sameScope) return;
    final result = await plannerSheet<String>(
        context,
        'Sort habits',
        (context) => Column(children: [
              for (final entry in {
                'Custom order': LibrarySort.manual,
                'Name A–Z': LibrarySort.name,
                'Activity time': LibrarySort.time
              }.entries)
                ListTile(
                    title: Text(context.tr(entry.key)),
                    selected: sort == entry.value,
                    trailing: sort == entry.value
                        ? const Icon(Icons.check_rounded,
                            color: checklistPrimary)
                        : null,
                    onTap: () => Navigator.pop(context, entry.key)),
              const Divider(),
              ListTile(
                  title: Text(context.tr('Reorder habits')),
                  trailing: const Icon(Icons.drag_handle),
                  onTap: () => Navigator.pop(context, 'Reorder habits')),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Cancel'))),
            ]));
    if (!mounted || result == null) return;
    if (result == 'Reorder habits') {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        search.clear();
        category = null;
        weekday = null;
        status = LibraryStatus.all;
        sort = LibrarySort.manual;
        selected.clear();
        selecting = false;
        draftOrder = visible.map((h) => h.id).toList();
        reordering = true;
      });
    } else {
      filter(() => sort = result == 'Name A–Z'
          ? LibrarySort.name
          : result == 'Activity time'
              ? LibrarySort.time
              : LibrarySort.manual);
    }
  }

  Future<void> saveOrder() async {
    try {
      await save(orderLibraryHabits(items, draftOrder, now));
    } on StateError {
      notice('Habits changed. Review your selection and try again.');
      setState(() => reordering = false);
    }
  }

  String statusLabel(LibraryStatus s) => switch (s) {
        LibraryStatus.all => 'All',
        LibraryStatus.active => 'Active',
        LibraryStatus.archived => 'Archived'
      };
  String weekdayLabel(BuildContext context, int day) =>
      DateFormat.E(Localizations.localeOf(context).toLanguageTag())
          .format(DateTime(2026, 11, 1 + day));
  String daysLabel(BuildContext context, HabitPlan p) {
    final days = p.weekdays.toSet();
    if (days.length == 7) return context.tr('Every day');
    if (setEquals(days, {1, 2, 3, 4, 5})) return context.tr('Weekdays');
    if (setEquals(days, {6, 7})) return context.tr('Weekends');
    return (days.toList()..sort())
        .map((d) => weekdayLabel(context, d))
        .join(' · ');
  }

  String goal(BuildContext context, HabitPlan p) => p.type == 'checkbox'
      ? context.tr('Check-in')
      : p.type == 'duration'
          ? context.tr('{p0} minutes', {'p0': p.target})
          : '${context.tr('Count')} · ${p.target}${p.unit == 'count' ? '' : ' ${p.unit}'}';

  Widget row(BuildContext context, Habit h, {int? reorderIndex}) {
    final data = libraryData(h, now),
        p = libraryData(h, now).planOn(checklistDay(now));
    final clock = p.activityMinute == null
        ? context.tr('Anytime')
        : clockLabel(context, p.activityMinute!);
    final reminder = !h.reminderEnabled
        ? context.tr('Reminders off')
        : p.activityMinute == null
            ? clockLabel(context, h.reminderHour * 60 + h.reminderMinute)
            : context.tr(
                h.reminderLeadMinutes == 0
                    ? 'At activity time'
                    : '{p0} min before',
                {'p0': h.reminderLeadMinutes});
    return Padding(
        key: ValueKey('library-row-${h.id}'),
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
            color: selected.contains(h.id) ? checklistBorder : checklistSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: checklistBorder)),
            child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: reorderIndex != null
                    ? null
                    : () => selecting
                        ? setState(() {
                            if (!selected.add(h.id)) selected.remove(h.id);
                          })
                        : edit(h),
                onLongPress: reorderIndex != null
                    ? null
                    : () => setState(() {
                          selecting = true;
                          selected.add(h.id);
                        }),
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selecting)
                            Checkbox(
                                key: ValueKey('library-select-${h.id}'),
                                value: selected.contains(h.id),
                                onChanged: (_) => setState(() {
                                      if (!selected.add(h.id))
                                        selected.remove(h.id);
                                    }),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5)))
                          else
                            Padding(
                                padding:
                                    const EdgeInsets.only(top: 8, right: 10),
                                child: Icon(habitIcon(h.iconKey),
                                    color: checklistPrimary, size: 24)),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(h.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                Wrap(spacing: 8, runSpacing: 4, children: [
                                  Text(context.tr(data.category),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: checklistPrimary)),
                                  if (data.archived)
                                    Text(context.tr('Archived'),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: checklistMuted)),
                                ]),
                                const SizedBox(height: 8),
                                Text(goal(context, p),
                                    style: const TextStyle(
                                        fontSize: 12, color: checklistText)),
                                const SizedBox(height: 4),
                                Text('${daysLabel(context, p)} · $clock',
                                    style: const TextStyle(
                                        fontSize: 12, color: checklistMuted)),
                                if (reorderIndex == null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                      h.reminderEnabled
                                          ? context.tr('Reminder: {p0}',
                                              {'p0': reminder})
                                          : reminder,
                                      style: const TextStyle(
                                          fontSize: 11, color: checklistMuted)),
                                ],
                              ])),
                          if (reorderIndex != null)
                            ReorderableDragStartListener(
                                key: ValueKey('library-drag-${h.id}'),
                                index: reorderIndex,
                                child: const ColoredBox(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Icon(Icons.drag_handle,
                                            color: checklistMuted))))
                          else if (!selecting)
                            IconButton(
                                key: ValueKey('library-actions-${h.id}'),
                                tooltip: context.tr('Habit actions'),
                                onPressed: () => rowActions(h),
                                icon: const Icon(Icons.more_horiz,
                                    color: checklistMuted)),
                        ])))));
  }

  @override
  Widget build(BuildContext context) =>
      ChecklistSurface(child: Builder(builder: (context) {
        final active = items.where((h) => !libraryData(h, now).archived).length;
        final shown = visible;
        final byId = {for (final h in items) h.id: h};
        return PopScope(
            canPop: !busy && !reordering,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && !busy && reordering)
                setState(() => reordering = false);
            },
            child: Stack(children: [
              Scaffold(
                appBar: AppBar(
                    toolbarHeight:
                        MediaQuery.textScalerOf(context).scale(1) > 1.4
                            ? 88
                            : 64,
                    title: Text(
                        context
                            .tr(reordering ? 'Reorder habits' : 'All habits'),
                        maxLines: 2),
                    actions: [
                      if (!reordering && sameScope)
                        IconButton(
                            key: const ValueKey('library-selection-mode'),
                            tooltip: context
                                .tr(selecting ? 'Cancel' : 'Select habits'),
                            onPressed: () => setState(() {
                                  selecting = !selecting;
                                  selected.clear();
                                }),
                            icon: Icon(selecting
                                ? Icons.close
                                : Icons.checklist_rounded))
                    ]),
                body: !sameScope
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(context
                                .tr('Account changed. Reopen All habits.'))))
                    : reordering
                        ? Column(children: [
                            Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 20, 16),
                                child: Text(
                                    context.tr(
                                        'Drag to reorder. Daily routines keep their groups.'),
                                    style: const TextStyle(
                                        fontSize: 12, color: checklistMuted))),
                            Expanded(
                                child: ReorderableListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    buildDefaultDragHandles: false,
                                    itemCount: draftOrder
                                        .where(byId.containsKey)
                                        .length,
                                    onReorderItem: (oldIndex, newIndex) =>
                                        setState(() {
                                          final id =
                                              draftOrder.removeAt(oldIndex);
                                          draftOrder.insert(newIndex, id);
                                        }),
                                    itemBuilder: (context, index) {
                                      final ids = draftOrder
                                          .where(byId.containsKey)
                                          .toList();
                                      return row(context, byId[ids[index]]!,
                                          reorderIndex: index);
                                    })),
                          ])
                        : CustomScrollView(
                            key: const ValueKey('library-scroll'),
                            slivers: [
                                SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 4, 20, 16),
                                    sliver: SliverList.list(children: [
                                      Text(
                                          context.tr(
                                              '{p0} active · {p1} archived', {
                                            'p0': active,
                                            'p1': items.length - active
                                          }),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: checklistMuted)),
                                      const SizedBox(height: 16),
                                      TextField(
                                          key: const ValueKey('library-search'),
                                          controller: search,
                                          onChanged: (_) => filter(() {}),
                                          decoration: InputDecoration(
                                              labelText:
                                                  context.tr('Search habits'),
                                              prefixIcon:
                                                  const Icon(Icons.search),
                                              suffixIcon: search.text.isEmpty
                                                  ? null
                                                  : IconButton(
                                                      tooltip:
                                                          context.tr('Clear'),
                                                      onPressed: () =>
                                                          filter(search.clear),
                                                      icon: const Icon(
                                                          Icons.close)))),
                                      const SizedBox(height: 12),
                                      Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            OutlinedButton.icon(
                                                key: const ValueKey(
                                                    'library-filters'),
                                                onPressed: filters,
                                                icon: const Icon(
                                                    Icons.tune_rounded,
                                                    size: 18),
                                                label: Text(
                                                    context.tr('Filters'))),
                                            OutlinedButton.icon(
                                                key: const ValueKey(
                                                    'library-sort'),
                                                onPressed: sorting,
                                                icon: const Icon(
                                                    Icons.sort_rounded,
                                                    size: 18),
                                                label:
                                                    Text(context.tr('Sort'))),
                                          ]),
                                      const SizedBox(height: 8),
                                      Wrap(spacing: 8, children: [
                                        for (final s in LibraryStatus.values)
                                          ChoiceChip(
                                              key: ValueKey(
                                                  'library-status-${s.name}'),
                                              label: Text(
                                                  context.tr(statusLabel(s))),
                                              selected: status == s,
                                              onSelected: (_) =>
                                                  filter(() => status = s))
                                      ]),
                                      if (category != null || weekday != null)
                                        Wrap(spacing: 8, children: [
                                          if (category != null)
                                            InputChip(
                                                label:
                                                    Text(context.tr(category!)),
                                                onDeleted: () => filter(
                                                    () => category = null)),
                                          if (weekday != null)
                                            InputChip(
                                                label: Text(weekdayLabel(
                                                    context, weekday!)),
                                                onDeleted: () => filter(
                                                    () => weekday = null)),
                                        ]),
                                      const SizedBox(height: 12),
                                      if (selecting)
                                        Wrap(
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            spacing: 12,
                                            children: [
                                              Text(context.tr('{p0} selected',
                                                  {'p0': selected.length})),
                                              TextButton(
                                                  key: const ValueKey(
                                                      'library-select-visible'),
                                                  onPressed: shown.isEmpty
                                                      ? null
                                                      : () => setState(() {
                                                            if (shown.every(
                                                                (h) => selected
                                                                    .contains(h
                                                                        .id))) {
                                                              selected.clear();
                                                            } else {
                                                              selected.addAll(
                                                                  shown.map(
                                                                      (h) => h
                                                                          .id));
                                                            }
                                                          }),
                                                  child: Text(context.tr(shown
                                                              .isNotEmpty &&
                                                          shown.every((h) =>
                                                              selected.contains(
                                                                  h.id))
                                                      ? 'Clear selection'
                                                      : 'Select visible'))),
                                            ])
                                      else
                                        Text(
                                            context.tr('{p0} habits',
                                                {'p0': shown.length}),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: checklistMuted)),
                                    ])),
                                if (shown.isEmpty)
                                  SliverToBoxAdapter(
                                      child: Padding(
                                          padding: const EdgeInsets.all(32),
                                          child: Column(children: [
                                            const Icon(Icons.spa_outlined,
                                                size: 36,
                                                color: checklistPrimary),
                                            const SizedBox(height: 12),
                                            Text(
                                                context.tr(items.isEmpty
                                                    ? 'Plant your first daily habit 🌱'
                                                    : 'No matching habits'),
                                                textAlign: TextAlign.center),
                                            if (items.isNotEmpty)
                                              TextButton(
                                                  onPressed: () => filter(() {
                                                        search.clear();
                                                        category = null;
                                                        weekday = null;
                                                        status =
                                                            LibraryStatus.all;
                                                      }),
                                                  child: Text(context
                                                      .tr('Clear filters'))),
                                          ]))),
                                SliverPadding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    sliver: SliverList.builder(
                                        itemCount: shown.length,
                                        itemBuilder: (context, index) =>
                                            row(context, shown[index]))),
                                const SliverToBoxAdapter(
                                    child: SizedBox(height: 24)),
                              ]),
                bottomNavigationBar: !sameScope || (!selecting && !reordering)
                    ? null
                    : SafeArea(
                        top: false,
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                            child: reordering
                                ? Row(children: [
                                    TextButton(
                                        onPressed: () =>
                                            setState(() => reordering = false),
                                        child: Text(context.tr('Cancel'))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: FilledButton(
                                            onPressed: saveOrder,
                                            child:
                                                Text(context.tr('Save order'))))
                                  ])
                                : FilledButton.icon(
                                    key: const ValueKey('library-bulk-actions'),
                                    onPressed:
                                        selected.isEmpty ? null : bulkActions,
                                    icon: const Icon(Icons.tune_rounded),
                                    label: Text(context.tr(
                                        'Actions for {p0} habits',
                                        {'p0': selected.length}))))),
              ),
              if (busy)
                Positioned.fill(
                    child: ColoredBox(
                        color: const Color(0x990B1613),
                        child: Center(
                            child: Semantics(
                                label: context.tr('Saving changes'),
                                child: const CircularProgressIndicator(
                                    color: checklistPrimary)))))
            ]));
      }));
}
