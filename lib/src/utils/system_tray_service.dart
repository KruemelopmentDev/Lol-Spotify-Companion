import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lol_spotify_companion/src/l10n/app_localizations.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class SystemTrayService {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();

  Future<void> initSystemTray(BuildContext context) async {
    String trayIconPath = await _getTrayIconPath();
    final loc = AppLocalizations.of(context);
    // Initialize system tray
    await _systemTray.initSystemTray(
      title: "LoL Spotify",
      iconPath: trayIconPath,
    );

    // Setup menu
    await _menu.buildFrom([
      MenuItemLabel(
        label: loc.translate('show'),
        onClicked: (menuItem) async {
          await windowManager.show();
          await windowManager.focus();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: loc.translate('exit'),
        onClicked: (menuItem) async {
          await windowManager.destroy();
          exit(0);
        },
      ),
    ]);

    await _systemTray.setContextMenu(_menu);

    // Handle tray icon click
    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        Platform.isWindows
            ? windowManager.show()
            : _systemTray.popUpContextMenu();
      } else if (eventName == kSystemTrayEventRightClick) {
        Platform.isWindows
            ? _systemTray.popUpContextMenu()
            : windowManager.show();
      }
    });
  }

  Future<String> _getTrayIconPath() async {
    // Copy icon from assets to temp directory
    final tempDir = await getTemporaryDirectory();
    final iconFile = File(path.join(tempDir.path, 'app_icon.ico'));

    if (!await iconFile.exists()) {
      final byteData = await rootBundle.load('assets/app_icon.ico');
      await iconFile.writeAsBytes(byteData.buffer.asUint8List());
    }

    return iconFile.path;
  }

  Future<void> dispose() async {
    await _systemTray.destroy();
  }
}
