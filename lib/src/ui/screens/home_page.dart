import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app.dart';
import '../../l10n/app_localizations.dart';
import '../../models/champion.dart';
import '../../models/champion_song.dart';
import '../../services/riot_client_service.dart';
import '../../services/spotify_service.dart';
import '../dialogs/add_champion_dialog.dart';
import '../dialogs/connections_dialog.dart';
import '../widgets/hoverable_list_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<ChampionSong> championSongs = [];
  List<ChampionSong> filteredSongs = [];
  List<Champion> _allChampions = [];
  final TextEditingController searchController = TextEditingController();
  bool isLoading = true;

  final SpotifyService spotifyService = SpotifyService();
  final RiotClientService riotService = RiotClientService();
  bool spotifyConnected = false;
  bool riotConnected = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    riotService.connect();
    searchController.addListener(_filterSongs);
  }

  Future<void> _loadAllData() async {
    await _initServices();
    await _loadChampions();
    await loadSongData();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _initServices() async {
    // This part is the same as before
    await spotifyService.loadTokens();
    setState(() {
      spotifyConnected = spotifyService.isConnected;
    });
    riotService.onChampionSelected = _onChampionSelected;
    if (!spotifyConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showConnectionsDialog();
        }
      });
    }
  }

  Future<void> _loadChampions() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/champions.json',
      );
      final List<dynamic> jsonList = jsonDecode(jsonString);
      setState(() {
        _allChampions = jsonList.map((e) => Champion.fromJson(e)).toList();
        _allChampions.sort((a, b) => a.name.compareTo(b.name));
      });
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.translate('failed_load_champions')}: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  void _onChampionSelected(String championId) async {
    final song = championSongs.firstWhere(
      (s) => s.championId == championId,
      orElse: () => ChampionSong(
        championId: -1,
        championName: '',
        spotifyId: '',
        songName: '',
        artistName: '',
        imagePath: '',
      ),
    );

    if (song.spotifyId.isNotEmpty && spotifyConnected) {
      final success = await spotifyService.playSong(song.spotifyId);
      if (mounted) {
        final loc = AppLocalizations.of(context);
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '${loc.translate('now_playing')}: ${song.songName} - ${song.artistName}'
                  : loc.translate('playback_failed'),
            ),
            backgroundColor: success ? colorScheme.primary : colorScheme.error,
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

  Future<void> loadSongData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('championSongs');
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      setState(() {
        championSongs = jsonList.map((e) => ChampionSong.fromJson(e)).toList();
        filteredSongs = List.from(championSongs);
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
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.translate('export_success')}\n${file.path}'),
            backgroundColor: colorScheme.primary,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: colorScheme.onPrimary,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.translate('export_failed')}: $e'),
            backgroundColor: colorScheme.error,
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
          // Background is set by theme
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
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.translate('error')}: $e'),
            backgroundColor: colorScheme.error,
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

  void deleteChampionSong(int championId) {
    setState(() {
      championSongs.removeWhere((s) => s.championId == championId);
      _filterSongs();
    });
    saveData();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.primary, // Use scheme
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.music_note,
                color: colorScheme.onPrimary, // Use scheme
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              loc.translate('app_title'),
              style: TextStyle(
                color: colorScheme.secondary, // Use scheme (LoL Gold)
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        // Background, elevation, and iconTheme are set by AppBarTheme
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.link), // Color from AppBarTheme
                if (spotifyConnected && riotConnected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1DB954), // Keep Spotify Green
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
            icon: const Icon(Icons.language), // Color from AppBarTheme
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
            icon: const Icon(Icons.file_download), // Color from AppBarTheme
            tooltip: loc.translate('import_data'),
            onPressed: importData,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload), // Color from AppBarTheme
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
                  decoration: BoxDecoration(
                    color: colorScheme.surface, // Use scheme
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outline,
                        width: 1,
                      ), // Use scheme
                    ),
                  ),
                  child: TextField(
                    controller: searchController,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                    ), // Use scheme
                    decoration: InputDecoration(
                      hintText: loc.translate('search_placeholder'),
                      // hintStyle is set by inputDecorationTheme
                      prefixIcon: Icon(
                        Icons.search,
                        color: colorScheme.primary, // Use scheme
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color:
                                    colorScheme.onSurfaceVariant, // Use scheme
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
                                color: Colors.grey[800], // Keep neutral
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchController.text.isEmpty
                                    ? loc.translate('no_songs_added')
                                    : loc.translate('no_results'),
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[700], // Keep neutral
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
                                // Card color is set by cardTheme
                                margin: EdgeInsets.all(0),
                                elevation: 0,
                                color: colorScheme.onSecondary,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: ClipRRect(
                                    // You might want to add a border radius, too!
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.asset(
                                      song.imagePath,
                                      // These width/height properties on the Image
                                      // are now less important, but fine to keep.
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (
                                            context,
                                            error,
                                            stackTrace,
                                          ) => Container(
                                            width: 56,
                                            height: 56,
                                            color: colorScheme.primary,
                                            child: Center(
                                              child: Text(
                                                song.championName.toUpperCase(),
                                                style: TextStyle(
                                                  color: colorScheme.onPrimary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                    ),
                                  ),

                                  title: Text(
                                    song.championName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color:
                                          colorScheme.secondary, // Use scheme
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.music_note,
                                            size: 16,
                                            color: colorScheme
                                                .primary, // Use scheme
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              song.songName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: colorScheme
                                                    .onSurface, // Use scheme
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 16,
                                            color: colorScheme
                                                .tertiary, // Use scheme
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              song.artistName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: colorScheme
                                                    .onSurfaceVariant, // Use scheme
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
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: colorScheme
                                              .error, // Use scheme (Noxian Red)
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              // BG set by theme
                                              title: Center(
                                                child: Text(
                                                  loc.translate('delete_song'),
                                                ),
                                              ),
                                              content: Text(
                                                '${loc.translate('delete_confirm1')} ${song.songName} ${loc.translate('delete_confirm2')} ${song.artistName} ${loc.translate('delete_confirm3')} ${song.championName} ${loc.translate('delete_confirm4')}?',
                                              ),
                                              actions: [
                                                OutlinedButton(
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

                                                  style: ButtonStyle(
                                                    backgroundColor:
                                                        WidgetStateProperty.all(
                                                          colorScheme.error,
                                                        ),
                                                    foregroundColor:
                                                        WidgetStateProperty.all(
                                                          colorScheme.onError,
                                                        ),
                                                    shape: WidgetStateProperty.all(
                                                      RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              100,
                                                            ),
                                                      ),
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
            builder: (context) => AddChampionDialog(
              champions: _allChampions,
              onAdd: addChampionSong,
              spotifyService: spotifyService,
            ),
          );
        },
        icon: Icon(Icons.add, color: colorScheme.onPrimary), // Use scheme
        label: Text(
          loc.translate('add_champion'),
          style: TextStyle(
            color: colorScheme.onPrimary, // Use scheme
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            100,
          ), // Adjust the radius as needed
        ),
        // Background color is set by elevatedButtonTheme's parent (primary)
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
