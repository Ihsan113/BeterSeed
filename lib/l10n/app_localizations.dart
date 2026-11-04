import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// English is intentional on first launch, independent of the phone language.
/// Only interface messages are translated; user text and catalog names stay intact.
class AppLocalizations {
  const AppLocalizations(this.locale, this.messages);
  final Locale locale;
  final Map<String, String> messages;
  static const locales = [
    Locale('en', 'US'),
    Locale('id'),
    Locale('ja'),
    Locale('de'),
    Locale('fr'),
    Locale('es', '419'),
    Locale('pt', 'BR')
  ];
  static const languageNames = [
    '🇺🇸 English (United States)',
    '🇮🇩 Bahasa Indonesia',
    '🇯🇵 日本語',
    '🇩🇪 Deutsch',
    '🇫🇷 Français',
    '🇪🇸 Español (Latinoamérica)',
    '🇧🇷 Português (Brasil)'
  ];
  static const delegate = _StringsDelegate();
  static const english = AppLocalizations(Locale('en', 'US'), {});
  String text(String message, [Map<String, Object?> args = const {}]) {
    final translated = messages[message] ?? message;
    return translated.replaceAllMapped(RegExp(r'\{(p\d+)\}'),
        (m) => args.containsKey(m[1]) ? '${args[m[1]]}' : m[0]!);
  }
}

class _StringsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _StringsDelegate();
  @override
  bool isSupported(Locale locale) => AppLocalizations.locales
      .any((l) => l.languageCode == locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) {
    if (locale.languageCode == 'en')
      return SynchronousFuture(AppLocalizations.english);
    return _loadMessages(locale);
  }

  Future<AppLocalizations> _loadMessages(Locale locale) async {
    final data = jsonDecode(await rootBundle
        .loadString('assets/l10n/${locale.languageCode}.json')) as Map;
    return AppLocalizations(locale, data.cast<String, String>());
  }

  @override
  bool shouldReload(_StringsDelegate old) => false;
}

extension LocalizedContext on BuildContext {
  String tr(String message, [Map<String, Object?> args = const {}]) =>
      (Localizations.of<AppLocalizations>(this, AppLocalizations) ??
              AppLocalizations.english)
          .text(message, args);
}

class AppLocale extends ChangeNotifier {
  static const preference = 'betterseed_language_v1';
  Locale locale = AppLocalizations.locales.first;
  bool _disposed = false;
  Future<void> load() async {
    String? saved;
    try {
      saved = (await SharedPreferences.getInstance()).getString(preference);
    } catch (_) {
      return;
    }
    if (_disposed) return;
    locale = AppLocalizations.locales.firstWhere(
        (l) => l.toLanguageTag() == saved,
        orElse: () => AppLocalizations.locales.first);
    notifyListeners();
  }

  Future<void> select(Locale next) async {
    if (!AppLocalizations.locales.contains(next) || next == locale) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(preference, next.toLanguageTag()))
      throw StateError('Language not saved');
    if (_disposed) return;
    locale = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppLocaleScope extends InheritedNotifier<AppLocale> {
  const AppLocaleScope(
      {super.key, required AppLocale controller, required super.child})
      : super(notifier: controller);
  static AppLocale? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLocaleScope>()?.notifier;
}

Future<void> showLanguagePicker(BuildContext context) async {
  final controller = AppLocaleScope.of(context);
  if (controller == null) return;
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
              child: SingleChildScrollView(
                  child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(sheet.tr('App language'),
                  style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (var i = 0; i < AppLocalizations.locales.length; i++)
                ListTile(
                    key: ValueKey(
                        'language-${AppLocalizations.locales[i].toLanguageTag()}'),
                    title: Text(AppLocalizations.languageNames[i]),
                    selected: controller.locale == AppLocalizations.locales[i],
                    trailing: controller.locale == AppLocalizations.locales[i]
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () async {
                      try {
                        await controller.select(AppLocalizations.locales[i]);
                        if (sheet.mounted) Navigator.pop(sheet);
                      } catch (_) {
                        if (sheet.mounted)
                          ScaffoldMessenger.of(sheet).showSnackBar(SnackBar(
                              content: Text(sheet.tr(
                                  'Language could not be saved. Please try again.'))));
                      }
                    }),
            ]),
          ))));
}

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
      key: const ValueKey('choose-language'),
      tooltip: context.tr('App language'),
      onPressed: () => showLanguagePicker(context),
      icon: const Icon(Icons.language_rounded));
}
