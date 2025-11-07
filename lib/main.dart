import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final locale = prefs.getString('locale') ?? 'en';
  runApp(LoLSpotifyApp(locale: locale));
}

class AppLocalizations {
  final String locale;
  // 1. Remove 'late' and make 'final'
  final Map<String, String> _localizedStrings;

  // 2. Update constructor to accept the loaded map
  AppLocalizations(this.locale, this._localizedStrings);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // 3. REMOVE the entire Future<bool> load() method from this class.

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  // 1. Change constructor to be 'const' and remove the locale field
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'de'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // 2. Get the locale code from the 'locale' object
    final String localeCode = locale.languageCode;
    Map<String, String> localizedStrings;

    // 3. Move all loading logic here
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

    // 4. Create and return the fully initialized object
    return AppLocalizations(localeCode, localizedStrings);
  }

  // 5. 'shouldReload' can be false. Flutter reloads when the locale itself changes.
  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

class LoLSpotifyApp extends StatefulWidget {
  final String locale;
  const LoLSpotifyApp({super.key, required this.locale});

  static void setLocale(BuildContext context, String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
    final state = context.findAncestorStateOfType<_LoLSpotifyAppState>();
    state?.setLocale(locale);
  }

  @override
  State<LoLSpotifyApp> createState() => _LoLSpotifyAppState();
}

class _LoLSpotifyAppState extends State<LoLSpotifyApp> {
  late String _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
  }

  void setLocale(String locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoL Spotify Assistant',
      debugShowCheckedModeBanner: false,
      locale: Locale(_locale),
      localizationsDelegates: [
        const AppLocalizationsDelegate(), // Use your new const delegate
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0397AB),
        scaffoldBackgroundColor: const Color(0xFF010A13),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0397AB),
          secondary: Color(0xFFC8AA6E),
          surface: Color(0xFF091428),
          tertiary: Color(0xFF785A28),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF091428),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0397AB),
            foregroundColor: const Color(0xFF0A1428),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0A1428),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF1E2328)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF1E2328)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF0397AB), width: 2),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class Champion {
  final String id;
  final String name;
  final String imagePath;

  Champion({required this.id, required this.name, required this.imagePath});

  factory Champion.fromJson(Map<String, dynamic> json) => Champion(
    id: json['id'],
    name: json['name'],
    imagePath: json['imagePath'],
  );
}

class ChampionSong {
  final String championId;
  final String championName;
  final String spotifyId;
  final String songName;
  final String artistName;

  ChampionSong({
    required this.championId,
    required this.championName,
    required this.spotifyId,
    required this.songName,
    required this.artistName,
  });

  Map<String, dynamic> toJson() => {
    'championId': championId,
    'championName': championName,
    'spotifyId': spotifyId,
    'songName': songName,
    'artistName': artistName,
  };

  factory ChampionSong.fromJson(Map<String, dynamic> json) => ChampionSong(
    championId: json['championId'],
    championName: json['championName'],
    spotifyId: json['spotifyId'],
    songName: json['songName'],
    artistName: json['artistName'],
  );
}

class SpotifyService {
  String? accessToken;
  String? refreshToken;
  DateTime? tokenExpiry;

  bool get isConnected =>
      accessToken != null && (tokenExpiry?.isAfter(DateTime.now()) ?? false);

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('spotify_access_token');
    refreshToken = prefs.getString('spotify_refresh_token');
    final expiryStr = prefs.getString('spotify_token_expiry');
    if (expiryStr != null) {
      tokenExpiry = DateTime.parse(expiryStr);
    }
  }

  Future<void> saveTokens(String access, String? refresh, int expiresIn) async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = access;
    tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

    await prefs.setString('spotify_access_token', access);
    await prefs.setString(
      'spotify_token_expiry',
      tokenExpiry!.toIso8601String(),
    );

    if (refresh != null) {
      refreshToken = refresh;
      await prefs.setString('spotify_refresh_token', refresh);
    }
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('spotify_access_token');
    await prefs.remove('spotify_refresh_token');
    await prefs.remove('spotify_token_expiry');
    accessToken = null;
    refreshToken = null;
    tokenExpiry = null;
  }

  Future<bool> playSong(String spotifyId) async {
    if (!isConnected) return false;

    try {
      final response = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/play'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'uris': ['spotify:track:$spotifyId'],
        }),
      );

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class RiotClientService {
  WebSocket? _socket;
  bool isConnected = false;
  Function(String championId)? onChampionSelected;

  Future<void> connect() async {
    try {
      // Try to connect to local League Client (LCU)
      // Port and auth would need to be read from lockfile
      // This is a simplified example
      isConnected = true;
    } catch (e) {
      isConnected = false;
    }
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
    isConnected = false;
  }

  void startListening() {
    // Simulate champion selection events
    // In real implementation, this would parse LCU WebSocket events
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<ChampionSong> championSongs = [];
  List<ChampionSong> filteredSongs = [];
  final TextEditingController searchController = TextEditingController();
  bool isLoading = true;

  final SpotifyService spotifyService = SpotifyService();
  final RiotClientService riotService = RiotClientService();
  bool spotifyConnected = false;
  bool riotConnected = false;

  @override
  void initState() {
    super.initState();
    loadData();
    searchController.addListener(_filterSongs);
    _initServices();
  }

  Future<void> _initServices() async {
    await spotifyService.loadTokens();
    setState(() {
      spotifyConnected = spotifyService.isConnected;
    });

    riotService.onChampionSelected = _onChampionSelected;
  }

  void _onChampionSelected(String championId) async {
    final song = championSongs.firstWhere(
      (s) => s.championId == championId,
      orElse: () => ChampionSong(
        championId: '',
        championName: '',
        spotifyId: '',
        songName: '',
        artistName: '',
      ),
    );

    if (song.spotifyId.isNotEmpty && spotifyConnected) {
      final success = await spotifyService.playSong(song.spotifyId);
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '${loc.translate('now_playing')}: ${song.songName} - ${song.artistName}'
                  : loc.translate('playback_failed'),
            ),
            backgroundColor: success
                ? const Color(0xFF0397AB)
                : const Color(0xFFD13639),
          ),
        );
      }
    }
  }

  void _filterSongs() {
    setState(() {
      if (searchController.text.isEmpty) {
        filteredSongs = List.from(championSongs);
      } else {
        filteredSongs = championSongs
            .where(
              (song) =>
                  song.championName.toLowerCase().contains(
                    searchController.text.toLowerCase(),
                  ) ||
                  song.songName.toLowerCase().contains(
                    searchController.text.toLowerCase(),
                  ) ||
                  song.artistName.toLowerCase().contains(
                    searchController.text.toLowerCase(),
                  ),
            )
            .toList();
      }
    });
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('championSongs');
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      setState(() {
        championSongs = jsonList.map((e) => ChampionSong.fromJson(e)).toList();
        filteredSongs = List.from(championSongs);
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = championSongs.map((e) => e.toJson()).toList();
    await prefs.setString('championSongs', jsonEncode(jsonList));
  }

  Future<void> exportData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/lol_spotify_data_$timestamp.json');

      final jsonList = championSongs.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));

      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.translate('export_success')}\n${file.path}'),
            backgroundColor: const Color(0xFF0397AB),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.translate('export_failed')}: $e'),
            backgroundColor: const Color(0xFFD13639),
          ),
        );
      }
    }
  }

  Future<void> importData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final loc = AppLocalizations.of(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF091428),
          title: Text(loc.translate('import_data')),
          content: Text(
            '${loc.translate('import_instructions')}\n${directory.path}',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.translate('error')}: $e'),
            backgroundColor: const Color(0xFFD13639),
          ),
        );
      }
    }
  }

  void _showConnectionsDialog() {
    showDialog(
      context: context,
      builder: (context) => ConnectionsDialog(
        spotifyService: spotifyService,
        riotService: riotService,
        onConnectionChanged: () {
          setState(() {
            spotifyConnected = spotifyService.isConnected;
            riotConnected = riotService.isConnected;
          });
        },
      ),
    );
  }

  void addChampionSong(ChampionSong song) {
    setState(() {
      championSongs.removeWhere((s) => s.championId == song.championId);
      championSongs.add(song);
      championSongs.sort((a, b) => a.championName.compareTo(b.championName));
      _filterSongs();
    });
    saveData();
  }

  void deleteChampionSong(String championId) {
    setState(() {
      championSongs.removeWhere((s) => s.championId == championId);
      _filterSongs();
    });
    saveData();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0397AB),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.music_note,
                color: Color(0xFF010A13),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              loc.translate('app_title'),
              style: const TextStyle(
                color: Color(0xFFC8AA6E),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF091428),
        elevation: 0,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.link, color: Color(0xFF0397AB)),
                if (spotifyConnected && riotConnected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1DB954),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: loc.translate('connections'),
            onPressed: _showConnectionsDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: Color(0xFF0397AB)),
            tooltip: loc.translate('language'),
            onSelected: (String locale) {
              LoLSpotifyApp.setLocale(context, locale);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'en',
                child: Row(
                  children: [Text('🇬🇧'), SizedBox(width: 8), Text('English')],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'de',
                child: Row(
                  children: [Text('🇩🇪'), SizedBox(width: 8), Text('Deutsch')],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.file_download, color: Color(0xFF0397AB)),
            tooltip: loc.translate('import_data'),
            onPressed: importData,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload, color: Color(0xFF0397AB)),
            tooltip: loc.translate('export_data'),
            onPressed: exportData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF091428),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF1E2328), width: 1),
                    ),
                  ),
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: Color(0xFFA09B8C)),
                    decoration: InputDecoration(
                      hintText: loc.translate('search_placeholder'),
                      hintStyle: const TextStyle(color: Color(0xFF5B5A56)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF0397AB),
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Color(0xFF5B5A56),
                              ),
                              onPressed: () {
                                searchController.clear();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: filteredSongs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.music_off,
                                size: 64,
                                color: Colors.grey[800],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchController.text.isEmpty
                                    ? loc.translate('no_songs_added')
                                    : loc.translate('no_results'),
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredSongs.length,
                          itemBuilder: (context, index) {
                            final song = filteredSongs[index];
                            return HoverableListItem(
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFF0397AB),
                                    child: Text(
                                      song.championName[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF010A13),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    song.championName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFFC8AA6E),
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.music_note,
                                            size: 16,
                                            color: Color(0xFF0397AB),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              song.songName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFFA09B8C),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.person,
                                            size: 16,
                                            color: Color(0xFF785A28),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              song.artistName,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF5B5A56),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (spotifyConnected)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.play_arrow,
                                            color: Color(0xFF1DB954),
                                          ),
                                          tooltip: loc.translate('play_now'),
                                          onPressed: () async {
                                            final success = await spotifyService
                                                .playSong(song.spotifyId);
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    success
                                                        ? '${loc.translate('now_playing')}: ${song.songName}'
                                                        : loc.translate(
                                                            'playback_failed',
                                                          ),
                                                  ),
                                                  backgroundColor: success
                                                      ? const Color(0xFF0397AB)
                                                      : const Color(0xFFD13639),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Color(0xFFD13639),
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: const Color(
                                                0xFF091428,
                                              ),
                                              title: Text(
                                                loc.translate('delete_song'),
                                              ),
                                              content: Text(
                                                '${loc.translate('delete_confirm')} ${song.championName}?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text(
                                                    loc.translate('cancel'),
                                                  ),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    deleteChampionSong(
                                                      song.championId,
                                                    );
                                                    Navigator.pop(context);
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFFD13639,
                                                            ),
                                                      ),
                                                  child: Text(
                                                    loc.translate('delete'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddChampionDialog(onAdd: addChampionSong),
          );
        },
        icon: const Icon(Icons.add, color: Color(0xFF010A13)),
        label: Text(
          loc.translate('add_champion'),
          style: const TextStyle(
            color: Color(0xFF010A13),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0397AB),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    riotService.disconnect();
    super.dispose();
  }
}

class ConnectionsDialog extends StatefulWidget {
  final SpotifyService spotifyService;
  final RiotClientService riotService;
  final VoidCallback onConnectionChanged;

  const ConnectionsDialog({
    super.key,
    required this.spotifyService,
    required this.riotService,
    required this.onConnectionChanged,
  });

  @override
  State<ConnectionsDialog> createState() => _ConnectionsDialogState();
}

class _ConnectionsDialogState extends State<ConnectionsDialog> {
  final TextEditingController clientIdController = TextEditingController();
  final TextEditingController clientSecretController = TextEditingController();
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadSpotifyCredentials();
  }

  Future<void> _loadSpotifyCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    clientIdController.text = prefs.getString('spotify_client_id') ?? '';
    clientSecretController.text =
        prefs.getString('spotify_client_secret') ?? '';
  }

  Future<void> _connectSpotify() async {
    final loc = AppLocalizations.of(context);

    if (clientIdController.text.isEmpty ||
        clientSecretController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('enter_spotify_credentials')),
          backgroundColor: const Color(0xFFD13639),
        ),
      );
      return;
    }

    setState(() => isConnecting = true);

    // Save credentials
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spotify_client_id', clientIdController.text);
    await prefs.setString('spotify_client_secret', clientSecretController.text);

    // Build Spotify authorization URL
    final clientId = clientIdController.text;
    final redirectUri = 'http://localhost:8888/callback';
    final scope = 'user-modify-playback-state user-read-playback-state';

    final authUrl = Uri.parse(
      'https://accounts.spotify.com/authorize?'
      'client_id=$clientId&'
      'response_type=code&'
      'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
      'scope=${Uri.encodeComponent(scope)}',
    );

    // Open browser for authorization
    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('authorize_in_browser')),
            backgroundColor: const Color(0xFF0397AB),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    setState(() => isConnecting = false);
  }

  Future<void> _disconnectSpotify() async {
    await widget.spotifyService.disconnect();
    widget.onConnectionChanged();
    if (mounted) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('spotify_disconnected')),
          backgroundColor: const Color(0xFF0397AB),
        ),
      );
    }
  }

  Future<void> _connectRiot() async {
    await widget.riotService.connect();
    if (widget.riotService.isConnected) {
      widget.riotService.startListening();
    }
    widget.onConnectionChanged();

    if (mounted) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.riotService.isConnected
                ? loc.translate('riot_connected')
                : loc.translate('riot_connection_failed'),
          ),
          backgroundColor: widget.riotService.isConnected
              ? const Color(0xFF0397AB)
              : const Color(0xFFD13639),
        ),
      );
    }
  }

  Future<void> _disconnectRiot() async {
    widget.riotService.disconnect();
    widget.onConnectionChanged();
    if (mounted) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('riot_disconnected')),
          backgroundColor: const Color(0xFF0397AB),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: const Color(0xFF091428),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.link, color: Color(0xFFC8AA6E), size: 28),
                  const SizedBox(width: 12),
                  Text(
                    loc.translate('connections'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC8AA6E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Spotify Connection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1428),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.spotifyService.isConnected
                        ? const Color(0xFF1DB954)
                        : const Color(0xFF1E2328),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Spotify',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC8AA6E),
                                ),
                              ),
                              Text(
                                widget.spotifyService.isConnected
                                    ? loc.translate('connected')
                                    : loc.translate('disconnected'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: widget.spotifyService.isConnected
                                      ? const Color(0xFF1DB954)
                                      : const Color(0xFF5B5A56),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.spotifyService.isConnected)
                          Icon(
                            Icons.check_circle,
                            color: const Color(0xFF1DB954),
                          ),
                      ],
                    ),
                    if (!widget.spotifyService.isConnected) ...[
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('spotify_client_id'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA09B8C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: clientIdController,
                        style: const TextStyle(color: Color(0xFFA09B8C)),
                        decoration: InputDecoration(
                          hintText: loc.translate('enter_client_id'),
                          hintStyle: const TextStyle(color: Color(0xFF5B5A56)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        loc.translate('spotify_client_secret'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA09B8C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: clientSecretController,
                        obscureText: true,
                        style: const TextStyle(color: Color(0xFFA09B8C)),
                        decoration: InputDecoration(
                          hintText: loc.translate('enter_client_secret'),
                          hintStyle: const TextStyle(color: Color(0xFF5B5A56)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        loc.translate('spotify_instructions'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5B5A56),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isConnecting
                            ? null
                            : (widget.spotifyService.isConnected
                                  ? _disconnectSpotify
                                  : _connectSpotify),
                        icon: Icon(
                          widget.spotifyService.isConnected
                              ? Icons.link_off
                              : Icons.link,
                          color: const Color(0xFF010A13),
                        ),
                        label: Text(
                          widget.spotifyService.isConnected
                              ? loc.translate('disconnect')
                              : loc.translate('connect'),
                          style: const TextStyle(
                            color: Color(0xFF010A13),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.spotifyService.isConnected
                              ? const Color(0xFFD13639)
                              : const Color(0xFF1DB954),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Riot Client Connection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1428),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.riotService.isConnected
                        ? const Color(0xFF0397AB)
                        : const Color(0xFF1E2328),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0397AB),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.gamepad,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.translate('league_client'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC8AA6E),
                                ),
                              ),
                              Text(
                                widget.riotService.isConnected
                                    ? loc.translate('connected')
                                    : loc.translate('disconnected'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: widget.riotService.isConnected
                                      ? const Color(0xFF0397AB)
                                      : const Color(0xFF5B5A56),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.riotService.isConnected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF0397AB),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      loc.translate('riot_instructions'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5B5A56),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.riotService.isConnected
                            ? _disconnectRiot
                            : _connectRiot,
                        icon: Icon(
                          widget.riotService.isConnected
                              ? Icons.link_off
                              : Icons.link,
                          color: const Color(0xFF010A13),
                        ),
                        label: Text(
                          widget.riotService.isConnected
                              ? loc.translate('disconnect')
                              : loc.translate('connect'),
                          style: const TextStyle(
                            color: Color(0xFF010A13),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.riotService.isConnected
                              ? const Color(0xFFD13639)
                              : const Color(0xFF0397AB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    loc.translate('close'),
                    style: const TextStyle(color: Color(0xFF5B5A56)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    clientIdController.dispose();
    clientSecretController.dispose();
    super.dispose();
  }
}

class HoverableListItem extends StatefulWidget {
  final Widget child;

  const HoverableListItem({super.key, required this.child});

  @override
  State<HoverableListItem> createState() => _HoverableListItemState();
}

class _HoverableListItemState extends State<HoverableListItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..translate(0.0, isHovered ? -2.0 : 0.0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isHovered ? 1.0 : 0.85,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovered
                    ? const Color(0xFF0397AB).withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class ChampionListItem extends StatefulWidget {
  final Champion champion;
  final VoidCallback onTap;

  const ChampionListItem({
    super.key,
    required this.champion,
    required this.onTap,
  });

  @override
  State<ChampionListItem> createState() => _ChampionListItemState();
}

class _ChampionListItemState extends State<ChampionListItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isHovered
              ? const Color(0xFF0397AB).withValues(alpha: 0.2)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isHovered ? const Color(0xFF0397AB) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: ListTile(
          leading: AnimatedScale(
            scale: isHovered ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                widget.champion.imagePath,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 32,
                  height: 32,
                  color: const Color(0xFF0397AB),
                  child: Center(
                    child: Text(
                      widget.champion.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF010A13),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          title: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              color: isHovered
                  ? const Color(0xFFC8AA6E)
                  : const Color(0xFFA09B8C),
              fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
            ),
            child: Text(widget.champion.name),
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

class AddChampionDialog extends StatefulWidget {
  final Function(ChampionSong) onAdd;

  const AddChampionDialog({super.key, required this.onAdd});

  @override
  State<AddChampionDialog> createState() => _AddChampionDialogState();
}

class _AddChampionDialogState extends State<AddChampionDialog> {
  List<Champion> champions = [];
  List<Champion> filteredChampions = [];
  Champion? selectedChampion;
  final TextEditingController championController = TextEditingController();
  final TextEditingController spotifyController = TextEditingController();
  final TextEditingController songController = TextEditingController();
  final TextEditingController artistController = TextEditingController();
  final FocusNode championFocus = FocusNode();
  bool showDropdown = false;
  bool isLoadingChampions = true;

  @override
  void initState() {
    super.initState();
    loadChampions();
    championController.addListener(_filterChampions);
  }

  Future<void> loadChampions() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/champions.json',
      );
      final List<dynamic> jsonList = jsonDecode(jsonString);
      setState(() {
        champions = jsonList.map((e) => Champion.fromJson(e)).toList();
        filteredChampions = champions;
        isLoadingChampions = false;
      });
    } catch (e) {
      setState(() {
        isLoadingChampions = false;
      });
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.translate('failed_load_champions')}: $e'),
            backgroundColor: const Color(0xFFD13639),
          ),
        );
      }
    }
  }

  void _filterChampions() {
    setState(() {
      if (championController.text.isEmpty) {
        filteredChampions = champions;
        showDropdown = false;
        selectedChampion = null;
      } else {
        filteredChampions = champions
            .where(
              (c) => c.name.toLowerCase().contains(
                championController.text.toLowerCase(),
              ),
            )
            .toList();
        showDropdown = true;

        if (selectedChampion != null &&
            selectedChampion!.name != championController.text) {
          selectedChampion = null;
        }
      }
    });
  }

  void _selectChampion(Champion champion) {
    setState(() {
      selectedChampion = champion;
      championController.text = champion.name;
      showDropdown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: const Color(0xFF091428),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: isLoadingChampions
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.translate('add_champion_song'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC8AA6E),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    loc.translate('champion'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA09B8C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: championController,
                    focusNode: championFocus,
                    style: const TextStyle(color: Color(0xFFA09B8C)),
                    decoration: InputDecoration(
                      hintText: loc.translate('search_select_champion'),
                      hintStyle: const TextStyle(color: Color(0xFF5B5A56)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF0397AB),
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        showDropdown = true;
                      });
                    },
                  ),
                  if (showDropdown && filteredChampions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1428),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF1E2328)),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredChampions.length,
                        itemBuilder: (context, index) {
                          final champion = filteredChampions[index];
                          return ChampionListItem(
                            champion: champion,
                            onTap: () => _selectChampion(champion),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    loc.translate('spotify_track_id'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA09B8C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: spotifyController,
                    style: const TextStyle(color: Color(0xFFA09B8C)),
                    decoration: const InputDecoration(
                      hintText: 'e.g., 3n3Ppam7vgaVa1iaRUc9Lp',
                      hintStyle: TextStyle(color: Color(0xFF5B5A56)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.translate('song_name'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA09B8C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: songController,
                    style: const TextStyle(color: Color(0xFFA09B8C)),
                    decoration: InputDecoration(
                      hintText: loc.translate('enter_song_name'),
                      hintStyle: const TextStyle(color: Color(0xFF5B5A56)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.translate('artist_name'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA09B8C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: artistController,
                    style: const TextStyle(color: Color(0xFFA09B8C)),
                    decoration: InputDecoration(
                      hintText: loc.translate('enter_artist_name'),
                      hintStyle: const TextStyle(color: Color(0xFF5B5A56)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          loc.translate('cancel'),
                          style: const TextStyle(color: Color(0xFF5B5A56)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (selectedChampion == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  loc.translate('please_select_valid_champion'),
                                ),
                                backgroundColor: const Color(0xFFD13639),
                              ),
                            );
                            return;
                          }

                          if (spotifyController.text.isEmpty ||
                              songController.text.isEmpty ||
                              artistController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  loc.translate('please_fill_all_fields'),
                                ),
                                backgroundColor: const Color(0xFFD13639),
                              ),
                            );
                            return;
                          }

                          widget.onAdd(
                            ChampionSong(
                              championId: selectedChampion!.id,
                              championName: selectedChampion!.name,
                              spotifyId: spotifyController.text,
                              songName: songController.text,
                              artistName: artistController.text,
                            ),
                          );

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                loc.translate('song_added_success'),
                              ),
                              backgroundColor: const Color(0xFF0397AB),
                            ),
                          );
                        },
                        child: Text(loc.translate('add')),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    championController.dispose();
    spotifyController.dispose();
    songController.dispose();
    artistController.dispose();
    championFocus.dispose();
    super.dispose();
  }
}
