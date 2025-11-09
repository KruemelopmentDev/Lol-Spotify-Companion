import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RiotClientService {
  WebSocket? _socket;
  Timer? _connectTimer;
  bool isConnected = false;
  Function(String championId)? onChampionSelected;

  // The LCU `championId` for "no champion" is 0.
  // We track the last ID to avoid firing events for the same champion.
  int _lastChampionId = 0;

  // --- Public Methods ---

  /// Starts the service and begins trying to connect.
  Future<void> connect() async {
    // Start a timer that tries to connect every 5 seconds
    // if not already connected.
    _connectTimer?.cancel();
    _connectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!isConnected) {
        print('RiotClientService: Client not connected. Trying...');
        _tryConnect();
      }
    });
  }

  /// Stops the timer and disconnects from the WebSocket.
  void disconnect() {
    _connectTimer?.cancel();
    _connectTimer = null;
    _socket?.close();
    _socket = null;
    isConnected = false;
    _lastChampionId = 0;
    print('RiotClientService: Disconnected.');
  }

  // --- Private Connection Logic ---

  /// Gets the platform-specific path to the lockfile.
  File? _getLockfile() {
    String? path;
    if (Platform.isWindows) {
      // Default Windows install path.
      // This must be adjusted if League is installed elsewhere.
      path = 'C:\\Riot Games\\League of Legends\\lockfile';
    } else if (Platform.isMacOS) {
      // Default macOS install path.
      path = '/Applications/League of Legends.app/Contents/LoL/lockfile';
    }

    if (path != null && File(path).existsSync()) {
      return File(path);
    }
    return null;
  }

  /// Tries to find the lockfile, parse it, and connect to the WebSocket.
  void _tryConnect() async {
    final lockfile = _getLockfile();
    if (lockfile == null) {
      print('RiotClientService: Lockfile not found.');
      return;
    }

    try {
      final String content = await lockfile.readAsString();
      final List<String> parts = content.split(':');
      if (parts.length < 3) return;

      final String port = parts[2];
      final String password = parts[3];
      final String protocol = parts[4];

      // The auth header is a Basic auth with 'riot' as username and the password.
      final String auth = base64Encode(utf8.encode('riot:$password'));
      final String url = 'wss://127.0.0.1:$port/';

      // Create a custom HttpClient that trusts the self-signed LCU certificate
      final HttpClient client = HttpClient()
        ..badCertificateCallback =
            ((X509Certificate cert, String host, int port) => true);

      // Connect using the custom client
      _socket = await WebSocket.connect(
        url,
        headers: {'Authorization': 'Basic $auth'},
        customClient: client,
      );

      isConnected = true;
      _lastChampionId = 0;
      print('RiotClientService: Connected to LCU on port $port');

      // Once connected, listen for data and subscribe to events
      _socket!.listen(
        _onSocketData,
        onError: _onSocketError,
        onDone: _onSocketDone,
      );

      // Subscribe to the champ select session event
      _socket!.add('[5, "OnJsonApiEvent_lol-champ-select_v1_session"]');
    } catch (e) {
      print('RiotClientService: Connection attempt failed: $e');
      isConnected = false;
      _socket = null;
    }
  }

  // --- WebSocket Event Handlers ---

  /// Called when the WebSocket connection is closed.
  void _onSocketDone() {
    print('RiotClientService: LCU connection closed.');
    isConnected = false;
    _socket = null;
    _lastChampionId = 0;
  }

  /// Called when the WebSocket connection has an error.
  void _onSocketError(dynamic error) {
    print('RiotClientService: LCU connection error: $error');
    isConnected = false;
    _socket = null;
    _lastChampionId = 0;
  }

  /// Called when we receive data from the LCU WebSocket.
  void _onSocketData(dynamic data) {
    if (data is! String) return;

    try {
      final List<dynamic> json = jsonDecode(data);
      if (json.length < 3 ||
          json[1] != 'OnJsonApiEvent_lol-champ-select_v1_session') {
        return;
      }

      // Extract the event data
      final Map<String, dynamic>? eventData = json[2]?['data'];
      if (eventData == null) return;

      final List<dynamic>? myTeam = eventData['myTeam'];
      final int? localPlayerCellId = eventData['localPlayerCellId'];
      if (myTeam == null || localPlayerCellId == null) return;

      // Find our player in the team list
      final player = myTeam.firstWhere(
        (player) => player['cellId'] == localPlayerCellId,
        orElse: () => null,
      );

      if (player != null) {
        final int championId = player['championId'] ?? 0;

        // Check if champion changed and is not "no champion" (0)
        if (championId != 0 && championId != _lastChampionId) {
          _lastChampionId = championId;

          // Fire the callback with the champion ID as a String
          onChampionSelected?.call(championId.toString());
          print('RiotClientService: Champion selected: $championId');
        } else if (championId == 0) {
          _lastChampionId = 0;
        }
      }
    } catch (e) {
      print('RiotClientService: Error parsing WebSocket data: $e');
    }
  }

  // --- Public API ---
  // (startListening is now handled by connect())
  void startListening() {
    // This is now handled by _tryConnect
  }
}
