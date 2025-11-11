import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lol_spotify_companion/src/services/process_monitor.dart';
import 'package:lol_spotify_companion/src/utils/system_tray_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'src/l10n/app_localizations.dart';
import 'src/ui/screens/home_page.dart';
import 'src/utils/theme.dart';

class LoLSpotifyApp extends StatefulWidget {
  final String locale;
  const LoLSpotifyApp({super.key, required this.locale});

  static void setLocale(BuildContext context, String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
    if (!context.mounted) return;
    final state = context.findAncestorStateOfType<_LoLSpotifyAppState>();
    state?.setLocale(locale);
  }

  @override
  State<LoLSpotifyApp> createState() => _LoLSpotifyAppState();
}

class _LoLSpotifyAppState extends State<LoLSpotifyApp> with WindowListener {
  late String _locale;
  final SystemTrayService _systemTrayService = SystemTrayService();
  bool _trayInitialized = false;
  final ProcessMonitor _monitor = ProcessMonitor();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _locale = widget.locale;
    _monitor.setupListener((processName) {
      print('Process started: $processName');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('League of Legends Started!'),
          content: Text('$processName is now running'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    });
    _monitor.startMonitoring('LeagueClient.exe');
  }

  void setLocale(String locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  void dispose() {
    _systemTrayService.dispose();
    _monitor.stopMonitoring();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoL Spotify Assistant',
      debugShowCheckedModeBanner: false,

      theme: appTheme,

      locale: Locale(_locale),
      localizationsDelegates: [
        const AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],

      home: Builder(
        builder: (BuildContext innerContext) {
          if (!_trayInitialized) {
            _systemTrayService.initSystemTray(innerContext);
            _trayInitialized = true;
          }

          return const HomePage();
        },
      ),
    );
  }
}
