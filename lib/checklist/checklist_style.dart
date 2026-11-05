import 'package:flutter/material.dart';

const checklistBackground = Color(0xFF101C19);
const checklistSurface = Color(0xFF192A24);
const checklistBorder = Color(0xFF30453B);
const checklistPrimary = Color(0xFFB6DCC4);
const checklistMuted = Color(0xFFAFBFB5);
const checklistText = Color(0xFFF1F5EE);

class ChecklistSurface extends StatelessWidget {
  const ChecklistSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Theme(
        data: base.copyWith(
          scaffoldBackgroundColor: checklistBackground,
          colorScheme: base.colorScheme.copyWith(
              primary: checklistPrimary,
              onPrimary: checklistBackground,
              secondary: checklistPrimary,
              secondaryContainer: checklistBorder,
              onSecondaryContainer: checklistText,
              surface: checklistSurface,
              onSurface: checklistText,
              outline: checklistBorder),
          appBarTheme: AppBarTheme(
              backgroundColor: checklistBackground,
              foregroundColor: checklistText,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              titleTextStyle: base.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: checklistText)),
          dividerColor: checklistBorder,
          switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? checklistBackground
                      : checklistMuted),
              trackColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? checklistPrimary
                      : checklistBorder),
              trackOutlineColor:
                  const WidgetStatePropertyAll(Colors.transparent)),
          cardTheme: CardThemeData(
              color: checklistSurface,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: shape),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: checklistPrimary,
                  foregroundColor: checklistBackground,
                  minimumSize: const Size(48, 48),
                  shape: shape,
                  textStyle: base.textTheme.labelLarge
                      ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600))),
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                  foregroundColor: checklistPrimary,
                  minimumSize: const Size(48, 48),
                  shape: shape,
                  side: const BorderSide(color: checklistBorder))),
          chipTheme: base.chipTheme.copyWith(
              showCheckmark: false,
              backgroundColor: checklistSurface,
              selectedColor: checklistBorder,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              labelStyle: base.textTheme.labelLarge
                  ?.copyWith(color: checklistText, fontSize: 13)),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: checklistSurface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: checklistBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: checklistBorder)),
              labelStyle:
                  base.textTheme.bodyLarge?.copyWith(color: checklistMuted)),
          textTheme: base.textTheme
              .apply(bodyColor: checklistText, displayColor: checklistText),
        ),
        child: child);
  }
}
