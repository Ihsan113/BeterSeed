import 'dart:async';
import 'package:flutter/material.dart';
import '../checklist/checklist_data.dart';
import '../checklist/checklist_pickers.dart';
import '../checklist/checklist_style.dart';
import '../l10n/app_localizations.dart';
import 'focus_session.dart';

/// Only this HUD rebuilds on the one-second display tick. Garden stays a sibling.
class FocusHud extends StatefulWidget {
  const FocusHud(
      {super.key,
      required this.session,
      required this.title,
      required this.onCheckpoint,
      required this.onFinish,
      required this.onExit,
      required this.onTarget,
      required this.motion});
  final FocusSession session;
  final String title;
  final Future<void> Function() onCheckpoint, onFinish, onExit;
  final VoidCallback onTarget;
  final bool motion;
  @override
  State<FocusHud> createState() => _FocusHudState();
}

class _FocusHudState extends State<FocusHud> with WidgetsBindingObserver {
  Timer? tick;
  bool minimal = false, busy = false, notified = false, dayChanged = false;
  String? failure;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(refresh);
    notified = widget.session.reachedTarget;
    dayChanged = checklistDay(DateTime.now()) != widget.session.day;
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.session.running &&
          checklistDay(DateTime.now()) != widget.session.day) {
        dayChanged = true;
        widget.session.pause();
        unawaited(checkpoint());
      }
      if (widget.session.reachedTarget && !notified) {
        notified = true;
        widget.session.pause();
        unawaited(checkpoint());
        widget.onTarget();
      }
      if (widget.session.running && widget.session.elapsedSeconds % 5 == 0)
        unawaited(checkpoint());
      if (mounted && widget.session.running) setState(() {});
    });
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> checkpoint() async {
    try {
      await widget.onCheckpoint();
    } catch (_) {
      if (mounted)
        setState(() => failure = 'Progress could not be saved. Please retry.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      widget.session.pause();
      unawaited(checkpoint());
    }
  }

  @override
  void dispose() {
    tick?.cancel();
    widget.session.removeListener(refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget glass(Widget child) => Container(
      key: ValueKey('focus-glass-$minimal'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xD110241F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: checklistPrimary.withValues(alpha: .2))),
      child: child);

  Future<void> finish() async {
    widget.session.pause();
    setState(() => busy = true);
    try {
      await widget.onFinish();
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          failure = 'Progress could not be saved. Please retry.';
        });
    }
  }

  Future<void> reset() async {
    if (busy || widget.session.reachedTarget) return;
    widget.session.pause();
    await checkpoint();
    if (!mounted || widget.session.reachedTarget) return;
    final confirm = await plannerSheet<bool>(
        context,
        'Reset this session?',
        (context) => Column(children: [
              Text(context.tr(
                  'Unsaved focus time will be discarded. Previously saved progress stays.')),
              pickerActions(context, () => Navigator.pop(context, true),
                  saveLabel: 'Reset'),
            ]));
    if (confirm == true && mounted && !widget.session.reachedTarget) {
      widget.session.reset();
      notified = widget.session.reachedTarget;
      await checkpoint();
    }
  }

  @override
  Widget build(BuildContext context) => ChecklistSurface(
      child: Builder(
          builder: (context) => SafeArea(
                child: LayoutBuilder(builder: (context, box) {
                  final session = widget.session;
                  final seconds = session.elapsedSeconds;
                  final time =
                      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
                  final target = session.targetMinutes;
                  final tallText =
                      MediaQuery.textScalerOf(context).scale(1) > 1.5;
                  return Stack(children: [
                    Positioned(
                        top: 12,
                        left: 16,
                        right: 16,
                        child: glass(Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                  key: const ValueKey('exit-habit-focus'),
                                  tooltip: context.tr('Back'),
                                  onPressed: busy ? null : widget.onExit,
                                  icon: const Icon(Icons.arrow_back_rounded)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(widget.title,
                                        maxLines: minimal ? 1 : 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                    if (!minimal) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                          context.tr(
                                              '{p0} min focus', {'p0': target}),
                                          style: const TextStyle(
                                              color: checklistMuted,
                                              fontSize: 12))
                                    ],
                                  ])),
                              IconButton(
                                  key: const ValueKey('toggle-focus-hud'),
                                  tooltip: context.tr(minimal
                                      ? 'Show controls'
                                      : 'Minimal HUD'),
                                  onPressed: () =>
                                      setState(() => minimal = !minimal),
                                  icon: Icon(minimal
                                      ? Icons.expand_more
                                      : Icons.expand_less)),
                            ]))),
                    Positioned(
                        bottom: 12,
                        left: 16,
                        right: 16,
                        child: AnimatedSwitcher(
                            duration: widget.motion
                                ? const Duration(milliseconds: 200)
                                : Duration.zero,
                            child: glass(ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxHeight:
                                        box.maxHeight * (tallText ? .52 : .38)),
                                child: SingleChildScrollView(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                      Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                                child: Text(time,
                                                    key: const ValueKey(
                                                        'focus-elapsed'),
                                                    style: const TextStyle(
                                                        fontSize: 34,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        letterSpacing: 1))),
                                            if (!minimal) ...[
                                              SizedBox(
                                                  width: 28,
                                                  height: 28,
                                                  child: CircularProgressIndicator(
                                                      value:
                                                          (session.totalSeconds /
                                                                  (target * 60))
                                                              .clamp(0, 1),
                                                      strokeWidth: 2,
                                                      color: checklistPrimary,
                                                      backgroundColor:
                                                          checklistBorder)),
                                              const SizedBox(width: 12),
                                            ],
                                            Flexible(
                                                child: Text(
                                                    context.tr(
                                                        session.reachedTarget
                                                            ? 'Target reached'
                                                            : session.running
                                                                ? 'Focusing'
                                                                : 'Paused'),
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: session
                                                                .reachedTarget
                                                            ? checklistPrimary
                                                            : checklistMuted))),
                                          ]),
                                      if (!minimal) ...[
                                        const SizedBox(height: 8),
                                        Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                                context.tr('{p0} of {p1} min', {
                                                  'p0': session.totalSeconds ~/
                                                      60,
                                                  'p1': target
                                                }),
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: checklistMuted))),
                                        const SizedBox(height: 12),
                                        Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              FilledButton.icon(
                                                  key: const ValueKey(
                                                      'focus-toggle'),
                                                  onPressed: busy ||
                                                          session
                                                              .reachedTarget ||
                                                          dayChanged ||
                                                          checklistDay(DateTime
                                                                  .now()) !=
                                                              session.day
                                                      ? null
                                                      : () async {
                                                          if (session.running) {
                                                            session.pause();
                                                          } else {
                                                            session.start();
                                                          }
                                                          await checkpoint();
                                                        },
                                                  icon: Icon(session.running
                                                      ? Icons.pause_rounded
                                                      : Icons
                                                          .play_arrow_rounded),
                                                  label: Text(
                                                      context.tr(session.running
                                                          ? 'Pause'
                                                          : seconds > 0
                                                              ? 'Resume'
                                                              : 'Start'))),
                                              OutlinedButton(
                                                  key: const ValueKey(
                                                      'focus-finish'),
                                                  onPressed:
                                                      busy ? null : finish,
                                                  child: Text(
                                                      context.tr('Finish'))),
                                              IconButton(
                                                  key: const ValueKey(
                                                      'focus-reset'),
                                                  tooltip: context.tr('Reset'),
                                                  disabledColor: checklistMuted
                                                      .withValues(alpha: .38),
                                                  onPressed: busy ||
                                                          session.reachedTarget
                                                      ? null
                                                      : reset,
                                                  icon: const Icon(
                                                      Icons.restart_alt)),
                                            ]),
                                        const SizedBox(height: 6),
                                        Text(
                                            context.tr(dayChanged
                                                ? 'New day. Save this session before starting again.'
                                                : 'Focus pauses when you leave the app'),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: checklistMuted),
                                            textAlign: TextAlign.center),
                                        if (failure != null)
                                          Text(context.tr(failure!),
                                              style: const TextStyle(
                                                  color: Color(0xFFF0B9A2),
                                                  fontSize: 12)),
                                      ] else
                                        TextButton(
                                            onPressed: () =>
                                                setState(() => minimal = false),
                                            child: Text(
                                                context.tr('Show controls'))),
                                    ])))))),
                  ]);
                }),
              )));
}
