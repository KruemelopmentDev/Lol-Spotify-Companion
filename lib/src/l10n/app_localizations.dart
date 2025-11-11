import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final String locale;
  final Map<String, String> _localizedStrings;

  AppLocalizations(this.locale, this._localizedStrings);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'de'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final String localeCode = locale.languageCode;
    Map<String, String> localizedStrings;

    try {
      String jsonString = await rootBundle.loadString(
        'assets/i18n/$localeCode.json',
      );
      Map<String, dynamic> jsonMap = json.decode(jsonString);
      localizedStrings = jsonMap.map(
        (key, value) => MapEntry(key, value.toString()),
      );
    } catch (e) {
      localizedStrings = {};
    }
    return AppLocalizations(localeCode, localizedStrings);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
