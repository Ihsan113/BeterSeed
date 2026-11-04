import 'package:flutter/material.dart';

enum NoticeTone { info, success, warning, error }

Color noticeColor(NoticeTone tone) => switch (tone) {
      NoticeTone.success => const Color(0xFF9EF7BD),
      NoticeTone.warning => const Color(0xFFFFD28E),
      NoticeTone.error => const Color(0xFFFFB4AB),
      NoticeTone.info => const Color(0xFFA7DDE0),
    };
IconData noticeIcon(NoticeTone tone) => switch (tone) {
      NoticeTone.success => Icons.check_circle_outline_rounded,
      NoticeTone.warning => Icons.info_outline_rounded,
      NoticeTone.error => Icons.error_outline_rounded,
      NoticeTone.info => Icons.info_outline_rounded,
    };

/// The same accessible message surface for account status and form errors.
class AppNotice extends StatelessWidget {
  const AppNotice(
      {super.key,
      required this.message,
      this.tone = NoticeTone.info,
      this.action});
  final String message;
  final NoticeTone tone;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: noticeColor(tone).withValues(alpha: .07),
              border:
                  Border.all(color: noticeColor(tone).withValues(alpha: .24)),
              borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(noticeIcon(tone), size: 21, color: noticeColor(tone)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(message,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          height: 1.45)),
                  if (action != null) ...[const SizedBox(height: 8), action!],
                ])),
          ]),
        ),
      );
}

/// All confirmation dialogs share typography, safe scrolling and action spacing.
class AppDialog extends StatelessWidget {
  const AppDialog(
      {super.key,
      this.title,
      this.content,
      this.actions,
      this.icon = Icons.info_outline_rounded,
      this.tone = NoticeTone.info,
      this.scrollable = true});
  final Widget? title, content;
  final List<Widget>? actions;
  final IconData icon;
  final NoticeTone tone;
  final bool scrollable;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor:
                      tone == NoticeTone.error ? noticeColor(tone) : null,
                  foregroundColor: tone == NoticeTone.error
                      ? const Color(0xFF351310)
                      : null))),
      child: AlertDialog(
        backgroundColor: const Color(0xFF122B30),
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        constraints: const BoxConstraints(maxWidth: 440),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF30494C))),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        iconPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        icon: Align(
            alignment: Alignment.centerLeft,
            child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: noticeColor(tone).withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 24, color: noticeColor(tone)))),
        titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFFE5F1ED),
            fontWeight: FontWeight.w700,
            height: 1.2),
        contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
        contentTextStyle: theme.textTheme.bodyMedium
            ?.copyWith(color: const Color(0xFFC4D5D2), height: 1.5),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        actionsOverflowButtonSpacing: 6,
        scrollable: scrollable,
        title: title == null
            ? null
            : Align(alignment: Alignment.centerLeft, child: title!),
        content: content,
        actions: actions,
      ),
    );
  }
}

/// Floating, dismissible notifications shared by every app screen.
class AppToast extends SnackBar {
  AppToast(
      {super.key,
      required Widget content,
      NoticeTone tone = NoticeTone.info,
      Duration duration = const Duration(seconds: 5),
      SnackBarBehavior behavior = SnackBarBehavior.floating,
      SnackBarAction? action})
      : super(
          content: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(noticeIcon(tone), color: noticeColor(tone), size: 22),
            const SizedBox(width: 10),
            Expanded(
                child: DefaultTextStyle.merge(
                    style: const TextStyle(
                        color: Color(0xFFE5F1ED), fontSize: 14, height: 1.4),
                    child: content)),
          ]),
          backgroundColor: const Color(0xFF17353A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side:
                  BorderSide(color: noticeColor(tone).withValues(alpha: .26))),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          showCloseIcon: true,
          closeIconColor: const Color(0xFFDAE8E3),
          elevation: 6,
          duration: duration,
          behavior: behavior,
          action: action,
        );
}

ThemeData betterSeedTheme() => ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF071820),
      colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9EF7BD),
          brightness: Brightness.dark,
          surface: const Color(0xFF10272C)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0C2229),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF3D5356))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF3D5356))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF9EF7BD), width: 1.5)),
        errorMaxLines: 3,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF122B30),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: const Color(0xFF122B30),
        dialBackgroundColor: const Color(0xFF203F39),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF10272C),
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0xB3000000),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
    );
