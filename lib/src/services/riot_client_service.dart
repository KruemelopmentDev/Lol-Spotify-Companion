import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class RiotClientService with ChangeNotifier {
  WebSocket? _socket;
  Timer? _connectTimer;
  bool isConnected = false;
  Function(String championId)? onChampionSelected;
  int _lastChampionId = 0;

  Future<void> connect() async {
    tryConnect();
    _connectTimer?.cancel();
    _connectTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!isConnected) {
        tryConnect();
      }
    });
  }

  void disconnect() {
    _connectTimer?.cancel();
    _connectTimer = null;
    _socket?.close();
    _socket = null;
    isConnected = false;
    _lastChampionId = 0;
  }

  File? _getLockfile() {
    String? path;
    if (Platform.isWindows) {
      path = 'C:\\Riot Games\\League of Legends\\lockfile';
    } else if (Platform.isMacOS) {
      path = '/Applications/League of Legends.app/Contents/LoL/lockfile';
    }

    if (path != null && File(path).existsSync()) {
      return File(path);
    }
    return null;
  }

  void tryConnect() async {
    final lockfile = _getLockfile();
    if (lockfile == null) {
      return;
    }

    try {
      final String content = await lockfile.readAsString();
      final List<String> parts = content.split(':');
      if (parts.length < 3) return;

      final String port = parts[2];
      final String password = parts[3];

      final String auth = base64Encode(utf8.encode('riot:$password'));
      final String url = 'wss://127.0.0.1:$port/';

      final HttpClient client = HttpClient()
        ..badCertificateCallback =
            ((X509Certificate cert, String host, int port) => true);

      _socket = await WebSocket.connect(
        url,
        headers: {'Authorization': 'Basic $auth'},
        customClient: client,
      );

      isConnected = true;
      _lastChampionId = 0;

      _socket!.listen(
        _onSocketData,
        onError: _onSocketError,
        onDone: _onSocketDone,
      );

      _socket!.add('[5, "OnJsonApiEvent_lol-champ-select_v1_session"]');
      notifyListeners();
    } catch (e) {
      isConnected = false;
      _socket = null;
    }
  }

  void _onSocketDone() {
    isConnected = false;
    _socket = null;
    _lastChampionId = 0;
    notifyListeners();
  }

  void _onSocketError(dynamic error) {
    isConnected = false;
    _socket = null;
    _lastChampionId = 0;
    notifyListeners();
  }

  void _onSocketData(dynamic data) {
    if (data is! String) return;

    try {
      final List<dynamic> json = jsonDecode(data);
      if (json.length < 3 ||
          json[1] != 'OnJsonApiEvent_lol-champ-select_v1_session') {
        return;
      }

      final Map<String, dynamic>? eventData = json[2]?['data'];
      if (eventData == null) return;

      final Map<String, dynamic>? timer = eventData['timer'];
      if (timer == null) return;

      final String? phase = timer['phase'];
      if (phase == null || phase != 'FINALIZATION') {
        _lastChampionId = 0;
        return;
      }

      final List<dynamic>? myTeam = eventData['myTeam'];
      final int? localPlayerCellId = eventData['localPlayerCellId'];
      if (myTeam == null || localPlayerCellId == null) return;

      final player = myTeam.firstWhere(
        (player) => player['cellId'] == localPlayerCellId,
        orElse: () => null,
      );

      if (player != null) {
        final int championId = player['championId'] ?? 0;
        if (championId != 0 && championId != _lastChampionId) {
          _lastChampionId = championId;
          onChampionSelected?.call(championId.toString());
        } else if (championId == 0) {
          _lastChampionId = 0;
        }
      }
    } catch (e) {}
  }
}
