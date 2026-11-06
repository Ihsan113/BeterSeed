import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import 'checklist_style.dart';

String goalLabel(String type) => switch (type) {
      'count' => 'Count',
      'duration' => 'Duration',
      _ => 'Check-in'
    };
String clockLabel(BuildContext context, int minute) =>
    TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

Future<T?> plannerSheet<T>(BuildContext context, String title,
        Widget Function(BuildContext) content) =>
    showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: checklistBackground,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => ChecklistSurface(
            child: Builder(
                builder: (context) => Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom),
                    child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * .85),
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(context.tr(title),
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 20),
                                  content(context),
                                ])))))));

Widget pickerActions(BuildContext context, VoidCallback save,
        {String saveLabel = 'Save'}) =>
    Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Row(children: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Cancel'))),
          const SizedBox(width: 12),
          Expanded(
              child: FilledButton(
                  onPressed: save, child: Text(context.tr(saveLabel)))),
        ]));

class GoalTypeSelector extends StatelessWidget {
  const GoalTypeSelector(
      {super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final type in ['checkbox', 'count', 'duration'])
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                  selected: type == value,
                  button: true,
                  child: Material(
                      color: type == value ? checklistBorder : checklistSurface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: type == value
                                  ? checklistPrimary
                                  : checklistBorder)),
                      child: InkWell(
                          key: ValueKey('goal-type-$type'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onChanged(type),
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(children: [
                                Icon(
                                    type == 'checkbox'
                                        ? Icons.check_rounded
                                        : type == 'count'
                                            ? Icons.add_rounded
                                            : Icons.timer_outlined,
                                    color: checklistPrimary),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(context.tr(goalLabel(type)),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text(
                                          context.tr(type == 'checkbox'
                                              ? 'Done or not yet'
                                              : type == 'count'
                                                  ? 'Build progress one step at a time'
                                                  : 'Focus with your living garden'),
                                          style: const TextStyle(
                                              color: checklistMuted,
                                              fontSize: 12)),
                                    ])),
                                if (type == value)
                                  const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(Icons.check_rounded,
                                          size: 18, color: checklistPrimary)),
                              ]))))))
      ]);
}

class HabitCategoryPicker {
  static Future<String?> show(BuildContext context, String current) {
    var selected = current;
    return plannerSheet<String>(context, 'Category', (context) {
      return StatefulBuilder(
          builder: (context, update) => Column(children: [
                for (final category in [
                  'Morning',
                  'Afternoon',
                  'Evening',
                  'Custom'
                ])
                  ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      tileColor: selected == category ? checklistBorder : null,
                      leading: Icon(switch (category) {
                        'Morning' => Icons.wb_sunny_outlined,
                        'Afternoon' => Icons.light_mode_outlined,
                        'Evening' => Icons.dark_mode_outlined,
                        _ => Icons.grid_view_rounded
                      }),
                      title: Text(context.tr(category)),
                      trailing: selected == category
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => update(() => selected = category)),
                pickerActions(context, () => Navigator.pop(context, selected)),
              ]));
    });
  }
}

class ScheduleDayPicker {
  static Future<Set<int>?> show(BuildContext context, Set<int> current) {
    var days = {...current};
    return plannerSheet<Set<int>>(context, 'Activity days', (context) {
      return StatefulBuilder(
          builder: (context, update) =>
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final preset in ['Every day', 'Weekdays', 'Weekends'])
                    ActionChip(
                        label: Text(context.tr(preset)),
                        onPressed: () =>
                            update(() => days = preset == 'Every day'
                                ? {1, 2, 3, 4, 5, 6, 7}
                                : preset == 'Weekdays'
                                    ? {1, 2, 3, 4, 5}
                                    : {6, 7}))
                ]),
                const SizedBox(height: 12),
                for (var i = 1; i <= 7; i++)
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(DateFormat.EEEE(
                              Localizations.localeOf(context).toLanguageTag())
                          .format(DateTime(2026, 11, 1 + i))),
                      value: days.contains(i),
                      onChanged: (v) => update(() {
                            if (v == true) {
                              days.add(i);
                            } else if (days.length > 1) {
                              days.remove(i);
                            }
                          })),
                Text(context.tr('Choose at least one activity day'),
                    style:
                        const TextStyle(color: checklistMuted, fontSize: 12)),
                pickerActions(context, () => Navigator.pop(context, days)),
              ]));
    });
  }
}

class ActivityTimePicker {
  static Future<int?> show(BuildContext context, int? current,
      {bool allowAnytime = true}) async {
    final hour = TextEditingController(
        text: '${(current ?? 420) ~/ 60}'.padLeft(2, '0'));
    final minute =
        TextEditingController(text: '${(current ?? 420) % 60}'.padLeft(2, '0'));
    final key = GlobalKey<FormState>();
    var anytime = allowAnytime && current == null;
    final result = await plannerSheet<int>(
        context, allowAnytime ? 'Activity time' : 'Reminder time', (context) {
      return StatefulBuilder(
          builder: (context, update) => Form(
              key: key,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (allowAnytime) ...[
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.tr('Anytime')),
                          value: anytime,
                          onChanged: (v) => update(() => anytime = v)),
                      const SizedBox(height: 16),
                    ],
                    if (!anytime)
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: TextFormField(
                                    key: const ValueKey('time-hour'),
                                    controller: hour,
                                    onTap: () => hour.selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset: hour.text.length),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.number,
                                    maxLength: 2,
                                    decoration: InputDecoration(
                                        counterText: '',
                                        labelText: context.tr('Hour (0–23)')),
                                    validator: (v) {
                                      final n = int.tryParse(v ?? '');
                                      return n == null || n < 0 || n > 23
                                          ? context.tr('Invalid time')
                                          : null;
                                    })),
                            const SizedBox(width: 16),
                            Expanded(
                                child: TextFormField(
                                    key: const ValueKey('time-minute'),
                                    controller: minute,
                                    onTap: () => minute.selection =
                                        TextSelection(
                                            baseOffset: 0,
                                            extentOffset: minute.text.length),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    textInputAction: TextInputAction.done,
                                    keyboardType: TextInputType.number,
                                    maxLength: 2,
                                    decoration: InputDecoration(
                                        counterText: '',
                                        labelText: context.tr('Minute (0–59)')),
                                    validator: (v) {
                                      final n = int.tryParse(v ?? '');
                                      return n == null || n < 0 || n > 59
                                          ? context.tr('Invalid time')
                                          : null;
                                    })),
                          ]),
                    Text(
                        context.tr(
                            'Activity time is independent of notifications'),
                        style: const TextStyle(
                            color: checklistMuted, fontSize: 12)),
                    pickerActions(context, () {
                      if (anytime || key.currentState!.validate())
                        Navigator.pop(
                            context,
                            anytime
                                ? -1
                                : int.parse(hour.text) * 60 +
                                    int.parse(minute.text));
                    }),
                  ])));
    });
    // The route animates out before its editing controllers are released.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    hour.dispose();
    minute.dispose();
    return result;
  }
}

class ReminderChoice {
  const ReminderChoice(this.enabled, this.minute, this.lead);
  final bool enabled;
  final int minute, lead;
}

class ReminderPicker {
  static Future<ReminderChoice?> show(
      BuildContext context, ReminderChoice current, int? activity) {
    var enabled = current.enabled;
    var minute = current.minute;
    var lead = current.lead;
    return plannerSheet<ReminderChoice>(context, 'Reminder', (context) {
      return StatefulBuilder(
          builder: (context, update) =>
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Enable reminder')),
                    value: enabled,
                    onChanged: (v) => update(() => enabled = v)),
                if (enabled && activity != null)
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final n in [0, 5, 15, 30, 60])
                      ChoiceChip(
                          showCheckmark: false,
                          selected: lead == n,
                          label: Text(context.tr(
                              n == 0 ? 'At activity time' : '{p0} min before',
                              {'p0': n})),
                          onSelected: (_) => update(() => lead = n))
                  ]),
                if (enabled && activity == null)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: Text(context.tr('Reminder time')),
                      subtitle: Text(clockLabel(context, minute)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final value = await ActivityTimePicker.show(
                            context, minute,
                            allowAnytime: false);
                        if (value != null && context.mounted)
                          update(() => minute = value);
                      }),
                pickerActions(
                    context,
                    () => Navigator.pop(
                        context, ReminderChoice(enabled, minute, lead))),
              ]));
    });
  }
}

class NumericGoalSheet {
  static Future<int?> show(BuildContext context, int current,
      {String title = 'Target', int minimum = 1, int maximum = 100000}) async {
    final text = TextEditingController(text: '$current');
    final form = GlobalKey<FormState>();
    final result = await plannerSheet<int>(
        context,
        title,
        (context) => Form(
            key: form,
            child: Column(children: [
              TextFormField(
                  key: const ValueKey('numeric-value'),
                  controller: text,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: context.tr('Value'),
                      helperText: '$minimum–$maximum'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < minimum || n > maximum
                        ? context.tr('Enter a value from {p0} to {p1}',
                            {'p0': minimum, 'p1': maximum})
                        : null;
                  }),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(
                    tooltip: context.tr('Decrease'),
                    onPressed: () => text.text =
                        '${((int.tryParse(text.text) ?? minimum) - 1).clamp(minimum, maximum)}',
                    icon: const Icon(Icons.remove)),
                IconButton(
                    tooltip: context.tr('Increase'),
                    onPressed: () => text.text =
                        '${((int.tryParse(text.text) ?? minimum) + 1).clamp(minimum, maximum)}',
                    icon: const Icon(Icons.add)),
              ]),
              pickerActions(context, () {
                if (form.currentState!.validate())
                  Navigator.pop(context, int.parse(text.text));
              }),
            ])));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    text.dispose();
    return result;
  }
}

class HabitActionSheet {
  static Future<String?> show(BuildContext context, List<String> actions) =>
      plannerSheet<String>(
          context,
          'Habit actions',
          (context) => Column(children: [
                for (final action in actions)
                  ListTile(
                      title: Text(context.tr(action)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, action)),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('Cancel'))),
              ]));
}
