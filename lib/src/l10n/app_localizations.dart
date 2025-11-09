import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Handles holding and providing the translated strings
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

// Handles loading the correct localization file from assets
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
      print("Error loading localization file for '$localeCode': $e");
      localizedStrings = {}; // Default to empty on failure
    }

    // Return the fully initialized object
    return AppLocalizations(localeCode, localizedStrings);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
