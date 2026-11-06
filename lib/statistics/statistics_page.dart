import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../checklist/checklist_data.dart';
import '../checklist/checklist_pickers.dart';
import '../checklist/checklist_style.dart';
import '../checklist/habit_icons.dart';
import '../data/habit.dart';
import '../logic/water_progress.dart';
import '../data/garden_pack_registry.dart';
import 'garden_milestones.dart';
import '../l10n/app_localizations.dart';
import 'planner_insights.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage(
      {super.key,
      required this.habits,
      required this.progress,
      required this.tree,
      this.treeImages});
  final List<Habit> habits;
  final WaterProgress progress;
  final Widget tree;
  final List<String>? treeImages;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int period = 30, section = 0;
  String rate(InsightDay d) =>
      d.rate == null ? '—' : '${(d.rate! * 100).round()}%';
  Widget panel(Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: checklistSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: checklistBorder)),
      child: child);
  Widget heading(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(context.tr(text),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)));
  Widget metric(BuildContext context, String value, String label) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: checklistPrimary)),
        const SizedBox(height: 6),
        Text(context.tr(label),
            style: const TextStyle(fontSize: 12, color: checklistMuted)),
      ]);
  Widget metrics(BuildContext context, List<(String, String)> entries) =>
      LayoutBuilder(
          builder: (context, box) =>
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final e in entries)
                  SizedBox(
                      width: box.maxWidth < 290 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.5
                          ? box.maxWidth
                          : (box.maxWidth - 12) / 2,
                      child: panel(metric(context, e.$1, e.$2))),
              ]));
  Widget heatmap(BuildContext context, PlannerInsights insights,
          {HabitInsight? habit}) =>
      LayoutBuilder(builder: (context, box) {
        final map = habit?.days ?? insights.days;
        final dates = insights.dates;
        final width = box.maxWidth < 366 ? 366.0 : box.maxWidth;
        return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
                width: width,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        for (var weekday = 0; weekday < 7; weekday++)
                          Expanded(
                              child: Center(
                                  child: Text(
                                      DateFormat.E(
                                              Localizations.localeOf(context)
                                                  .toLanguageTag())
                                          .format(
                                              DateTime(2026, 11, 2 + weekday)),
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: checklistMuted)))),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(spacing: 5, runSpacing: 5, children: [
                        for (var gap = 1; gap < dates.first.weekday; gap++)
                          SizedBox(width: (width - 30) / 7, height: 48),
                        for (final day in dates)
                          Builder(builder: (context) {
                            final result = map[checklistDay(day)];
                            final value = result?.rate;
                            final label =
                                '${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(day)}: ${result == null ? context.tr('No scheduled record') : '${result.completed}/${result.scheduled}'}';
                            return Tooltip(
                                message: label,
                                child: Semantics(
                                    label: label,
                                    child: InkWell(
                                      onTap: () => plannerSheet<void>(
                                          context,
                                          'Daily history',
                                          (context) => Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Text(label),
                                                    const SizedBox(height: 16),
                                                    for (final item in insights
                                                        .byHabit
                                                        .where((h) =>
                                                            habit == null ||
                                                            h.habit.id ==
                                                                habit.habit.id))
                                                      if (item.days[checklistDay(day)] !=
                                                          null)
                                                        ListTile(
                                                            contentPadding:
                                                                EdgeInsets.zero,
                                                            leading: Icon(
                                                                habitIcon(item
                                                                    .habit
                                                                    .iconKey)),
                                                            title: Text(item
                                                                .habit.title),
                                                            subtitle:
                                                                Text('${item.days[checklistDay(day)]!.completed}/${item.days[checklistDay(day)]!.scheduled}')),
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child: Text(context
                                                            .tr('Close'))),
                                                  ])),
                                      child: Container(
                                          width: (width - 30) / 7,
                                          height: 48,
                                          alignment: Alignment.center,
                                          child: Text('${day.day}',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: (value ?? 0) > .5
                                                      ? checklistBackground
                                                      : checklistMuted)),
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                              color: value == null
                                                  ? checklistBackground
                                                  : Color.lerp(checklistBorder,
                                                      checklistPrimary, value),
                                              border: value == null
                                                  ? Border.all(
                                                      color: checklistBorder)
                                                  : null)),
                                    )));
                          })
                      ]),
                      const SizedBox(height: 12),
                      Text(context.tr('Empty cells have no scheduled record'),
                          style: const TextStyle(
                              color: checklistMuted, fontSize: 11)),
                    ])));
      });
  Widget breakdown(BuildContext context, Map<String, InsightDay> data) =>
      panel(Column(children: [
        for (final e in data.entries)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(
                    child: Text(context.tr(e.key),
                        style: const TextStyle(fontSize: 13))),
                const SizedBox(width: 8),
                Text(
                    '${e.value.completed}/${e.value.scheduled} · ${rate(e.value)}',
                    style:
                        const TextStyle(color: checklistPrimary, fontSize: 12)),
              ])),
      ]));

  void habitDetail(
          BuildContext context, HabitInsight habit, PlannerInsights insights) =>
      plannerSheet<void>(
          context,
          'Habit insights',
          (context) =>
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(habit.habit.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                metrics(context, [
                  (rate(habit.total), 'Completion rate'),
                  (
                    '${habit.total.completed}/${habit.total.scheduled}',
                    'Completed / scheduled'
                  ),
                  (
                    '${(habit.total.seconds / 60).toStringAsFixed(1)}',
                    'Recorded minutes'
                  ),
                  (
                    '${habit.averageMinutes.toStringAsFixed(1)}',
                    'Average minutes per scheduled day'
                  )
                ]),
                heading(context, 'History'),
                heatmap(context, insights, habit: habit),
                heading(context, 'Habit streak'),
                Text(context.tr('Active {p0} · best {p1}', {
                  'p0': habit.habit.checklist!.streak(insights.now),
                  'p1': habit.habit.checklist!.streak(insights.now, best: true)
                })),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final n in [7, 30, 100])
                    Chip(
                        avatar: Icon(
                            habit.habit.checklist!
                                        .streak(insights.now, best: true) >=
                                    n
                                ? Icons.emoji_events_outlined
                                : Icons.lock_outline,
                            size: 16),
                        label: Text('$n'))
                ]),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('Close'))),
              ]));

  @override
  Widget build(BuildContext context) =>
      ChecklistSurface(child: Builder(builder: (context) {
        final insights = PlannerInsights(widget.habits, DateTime.now(), period);
        return ListView(
            key: const ValueKey('statistics-page'),
            padding: const EdgeInsets.all(20),
            children: [
              Text(context.tr('Statistics'),
                  key: const ValueKey('statistics-title'),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.8)),
              const SizedBox(height: 6),
              Text(context.tr('Small steps, a clearer picture'),
                  style: const TextStyle(color: checklistMuted, fontSize: 13)),
              const SizedBox(height: 20),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                              showCheckmark: false,
                              key: ValueKey('stats-section-$i'),
                              label: Text(context.tr([
                                'Overview',
                                'Habit insights',
                                'Garden growth'
                              ][i])),
                              selected: section == i,
                              onSelected: (_) => setState(() => section = i))),
                  ])),
              const SizedBox(height: 12),
              if (section != 2) ...[
                Wrap(spacing: 8, children: [
                  for (final n in [7, 30, 90])
                    ChoiceChip(
                        showCheckmark: false,
                        label: Text(context.tr('{p0} days', {'p0': n})),
                        selected: period == n,
                        onSelected: (_) => setState(() => period = n))
                ]),
                const SizedBox(height: 16),
                if (insights.total.scheduled == 0)
                  panel(Column(children: [
                    const Icon(Icons.spa_outlined,
                        color: checklistPrimary, size: 32),
                    const SizedBox(height: 12),
                    Text(context.tr('Your story starts with one habit'),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                        context.tr(
                            'Recorded activity will appear here. Rest and unknown days are never failures.'),
                        style: const TextStyle(
                            color: checklistMuted, fontSize: 12),
                        textAlign: TextAlign.center)
                  ])),
              ],
              if (section == 0 && insights.total.scheduled > 0) ...[
                metrics(context, [
                  (rate(insights.total), 'Completion rate'),
                  ('${insights.total.completed}', 'Habit completions'),
                  ('${insights.activeStreak}', 'Active habit streak'),
                  ('${insights.bestStreak}', 'Best habit streak')
                ]),
                heading(context, 'Completion trend'),
                panel(_trend(context, insights)),
                heading(context, 'Activity calendar'),
                panel(heatmap(context, insights)),
              ],
              if (section == 1 && insights.total.scheduled > 0) ...[
                for (final habit in insights.byHabit)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                          color: checklistSurface,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Icon(habitIcon(habit.habit.iconKey),
                                  color: checklistPrimary),
                              title: Text(habit.habit.title),
                              subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${habit.total.completed}/${habit.total.scheduled} · ${rate(habit.total)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: checklistMuted)),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                            value: habit.total.rate ?? 0,
                                            minHeight: 3,
                                            color: checklistPrimary,
                                            backgroundColor: checklistBorder),
                                      ])),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  habitDetail(context, habit, insights)))),
                heading(context, 'By category'),
                breakdown(context, insights.categories),
                heading(context, 'By weekday'),
                breakdown(context, {
                  for (final e
                      in (insights.weekdays.entries.toList()
                        ..sort((a, b) => a.key.compareTo(b.key))))
                    DateFormat.EEEE(
                            Localizations.localeOf(context).toLanguageTag())
                        .format(DateTime(2026, 11, 1 + e.key)): e.value
                }),
              ],
              if (section == 2) ...[
                panel(Row(children: [
                  SizedBox(width: 96, height: 120, child: widget.tree),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            context.tr('Stage {p0}',
                                {'p0': widget.progress.treeStage + 1}),
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('${widget.progress.xp} XP',
                            style: const TextStyle(color: checklistPrimary)),
                      ]))
                ])),
                const SizedBox(height: 12),
                metrics(context, [
                  ('${widget.progress.totalEarned}', 'Water earned'),
                  ('${widget.progress.waterBalance}', 'Water available'),
                  ('${widget.progress.totalSpent}', 'Water used'),
                  ('${widget.progress.xp}', 'Tree XP')
                ]),
                heading(context, 'Milestones'),
                panel(GardenMilestones(
                    xp: widget.progress.xp,
                    treeImages: widget.treeImages ??
                        GardenPackRegistry.packs.first.trees)),
                heading(context, 'Habit contributions'),
                panel(Column(children: [
                  for (final h in widget.habits)
                    Builder(builder: (context) {
                      final credited =
                          (widget.progress.toJson()['credited'] as Map)
                              .values
                              .where((ids) => (ids as List).contains(h.id))
                              .length;
                      if (credited == 0) return const SizedBox.shrink();
                      return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(h.title),
                          trailing:
                              Text(context.tr('{p0} water', {'p0': credited})));
                    })
                ])),
                const SizedBox(height: 16),
                Text(
                    context.tr(
                        'Water is credited once per habit and day. It becomes XP when you water your tree.'),
                    style:
                        const TextStyle(color: checklistMuted, fontSize: 12)),
              ],
              const SizedBox(height: 24),
              Text(
                  context.tr(
                      'Based on recorded history. Older or missing details are not estimated.'),
                  style: const TextStyle(color: checklistMuted, fontSize: 11)),
            ]);
      }));

  Widget _trend(BuildContext context, PlannerInsights insights) {
    final dates = insights.dates;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var bucket = 0; bucket < 7; bucket++)
        Expanded(child: Builder(builder: (context) {
          final start = bucket * dates.length ~/ 7,
              end = (bucket + 1) * dates.length ~/ 7;
          var scheduled = 0, completed = 0;
          for (var i = start; i < end; i++) {
            final d = insights.days[checklistDay(dates[i])];
            scheduled += d?.scheduled ?? 0;
            completed += d?.completed ?? 0;
          }
          final value = scheduled == 0 ? null : completed / scheduled;
          return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(children: [
                Text(value == null ? '—' : '${(value * 100).round()}',
                    style:
                        const TextStyle(fontSize: 11, color: checklistMuted)),
                const SizedBox(height: 8),
                SizedBox(
                    height: 90,
                    child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                            height: value == null ? 2 : 4 + value * 86,
                            decoration: BoxDecoration(
                                color: value == null
                                    ? checklistBorder
                                    : checklistPrimary,
                                borderRadius: BorderRadius.circular(4))))),
                const SizedBox(height: 8),
                Text('${dates[start].day}',
                    style:
                        const TextStyle(fontSize: 11, color: checklistMuted)),
              ]));
        }))
    ]);
  }
}
