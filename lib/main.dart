import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final bool isAutostart = args.contains('--autostart');

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    WindowOptions windowOptions = const WindowOptions(
      size: Size(800, 800),
      title: 'LoL Spotify Companion',
      minimumSize: Size(800, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (isAutostart) {
        await windowManager.minimize();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }
  final prefs = await SharedPreferences.getInstance();
  final locale = prefs.getString('locale') ?? 'en';

  runApp(LoLSpotifyApp(locale: locale));
}
