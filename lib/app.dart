import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lol_spotify_companion/src/utils/system_tray_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'src/l10n/app_localizations.dart';
import 'src/ui/screens/home_page.dart';
import 'src/utils/theme.dart';

class LoLSpotifyApp extends StatefulWidget {
  final String locale;
  const LoLSpotifyApp({super.key, required this.locale});

  // Static method to allow any widget to change the app's locale
  static void setLocale(BuildContext context, String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);

    // Find the app's state and call the setLocale method
    final state = context.findAncestorStateOfType<_LoLSpotifyAppState>();
    state?.setLocale(locale);
  }

  @override
  State<LoLSpotifyApp> createState() => _LoLSpotifyAppState();
}

class _LoLSpotifyAppState extends State<LoLSpotifyApp> with WindowListener {
  late String _locale;
  final SystemTrayService _systemTrayService = SystemTrayService();

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
    if (Platform.isWindows) {
      windowManager.addListener(this);
      _initSystemTray();
    }
  }

  Future<void> _initSystemTray() async {
    await _systemTrayService.initSystemTray();
  }

  // Method to update the locale state, which rebuilds the MaterialApp
  void setLocale(String locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
      _systemTrayService.dispose();
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoL Spotify Assistant',
      debugShowCheckedModeBanner: false,

      // Theme is loaded from our separate theme file
      theme: appTheme,

      // Locale and localization settings
      locale: Locale(_locale),
      localizationsDelegates: [
        const AppLocalizationsDelegate(), // Our custom localizations
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],

      home: const HomePage(),
    );
  }
}
