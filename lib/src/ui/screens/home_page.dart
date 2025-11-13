import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lol_spotify_companion/src/services/process_monitor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

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
  final ProcessMonitor _monitor = ProcessMonitor();

  @override
  void initState() {
    super.initState();
    _loadAllData();
    riotService.connect();
    searchController.addListener(_filterSongs);
    _monitor.setupListener((processName) {
      riotService.connect();
    });
    _monitor.startMonitoring('LeagueClient.exe');
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
    final matchingSongs = championSongs
        .where((s) => s.championId == int.tryParse(championId))
        .toList();
    final song = matchingSongs.isEmpty
        ? ChampionSong(
            championId: -1,
            championName: '',
            spotifyId: '',
            songName: '',
            artistName: '',
            imagePath: '',
          )
        : matchingSongs[Random().nextInt(matchingSongs.length)];
    if (song.championId != -1 && spotifyConnected) {
      final success = await spotifyService.playSong(song.spotifyId);
      if (mounted) {
        final loc = AppLocalizations.of(context);
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '${song.songName} - ${song.artistName} ${loc.translate('now_playing')}'
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
        championSongs.sort((a, b) => a.championName.compareTo(b.championName));
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
      final file = File('${directory.path}\\lol_spotify_data_$timestamp.json');

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
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      final colorScheme = Theme.of(context).colorScheme;

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: loc.translate('select_import_file'),
      );

      if (result == null || result.files.single.path == null) {
        // User canceled the file picker
        return;
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);

      if (!await file.exists()) {
        throw Exception(loc.translate('file_not_found'));
      }

      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List<dynamic>;

      final importedSongs = jsonList
          .map((json) => ChampionSong.fromJson(json as Map<String, dynamic>))
          .toList();

      if (!mounted) return;

      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(loc.translate('confirm_import')),
          content: Text(
            '${loc.translate('import_count')}: ${importedSongs.length}\n${loc.translate('this_will_be_added_to_data')}',
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(colorScheme.primary),
                foregroundColor: WidgetStateProperty.all(colorScheme.onPrimary),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.only(bottom: 12, left: 24, right: 24),
                ),
              ),
              child: Text(loc.translate('import')),
            ),
          ],
        ),
      );

      if (shouldImport != true || !mounted) return;

      setState(() {
        importedSongs.sort((a, b) => a.championName.compareTo(b.championName));
        championSongs.addAll(importedSongs);
      });
      _filterSongs();
      saveData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${importedSongs.length} ${loc.translate('import_success')}',
            ),
            backgroundColor: colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.translate('import_failed')}: $e'),
            backgroundColor: colorScheme.error,
            duration: const Duration(seconds: 5),
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
      championSongs.add(song);
      championSongs.sort((a, b) => a.championName.compareTo(b.championName));
      _filterSongs();
    });
    saveData();
  }

  void deleteChampionSong(int championId, String spotifyID) {
    setState(() {
      championSongs.removeWhere(
        (s) => s.championId == championId && s.spotifyId == spotifyID,
      );
      _filterSongs();
    });
    saveData();
  }

  Future<void> deleteAllChampionSongs() async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Center(child: Text(loc.translate('delete_all_songs'))),
        content: Text(
          '${loc.translate('delete_all_confirm')} (${championSongs.length} Champion-Songs)',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
            ),
            child: Text(loc.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.error,
              ),
              foregroundColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.onError,
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              padding: WidgetStateProperty.all(
                const EdgeInsets.only(bottom: 12, left: 24, right: 24),
              ),
            ),
            child: Text(
              loc.translate('delete_all'),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      setState(() {
        championSongs.clear();
        _filterSongs();
      });
      await saveData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('all_songs_deleted')),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
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
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.music_note,
                color: colorScheme.onPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              loc.translate('app_title'),
              style: TextStyle(
                color: colorScheme.secondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.link),
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
            icon: const Icon(Icons.language),
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
            icon: const Icon(Icons.file_download),
            tooltip: loc.translate('import_data'),
            onPressed: importData,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
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
                    color: colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outline, width: 1),
                    ),
                  ),
                  child: TextField(
                    controller: searchController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: loc.translate('search_placeholder'),
                      prefixIcon: Icon(
                        Icons.search,
                        color: colorScheme.primary,
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: colorScheme.onSurfaceVariant,
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
                                margin: EdgeInsets.all(0),
                                elevation: 0,
                                color: colorScheme.onSecondary,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: ClipRRect(
                                    child: Image.asset(
                                      song.imagePath,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (
                                            context,
                                            error,
                                            stackTrace,
                                          ) => Container(
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
                                      color: colorScheme.secondary,
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
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              song.songName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: colorScheme.onSurface,
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
                                            color: colorScheme.tertiary,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              song.artistName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: colorScheme
                                                    .onSurfaceVariant,
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
                                          color: colorScheme.error,
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Center(
                                                child: Text(
                                                  loc.translate('delete_song'),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              content: Text(
                                                '${loc.translate('delete_confirm1')} ${song.songName} ${loc.translate('delete_confirm2')} ${song.artistName} ${loc.translate('delete_confirm3')} ${song.championName} ${loc.translate('delete_confirm4')}?',
                                                textAlign: TextAlign.center,
                                              ),
                                              actions: [
                                                OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 12,
                                                          left: 24,
                                                          right: 24,
                                                        ),
                                                  ),
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
                                                      song.spotifyId,
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
                                                    padding:
                                                        WidgetStateProperty.all(
                                                          const EdgeInsets.only(
                                                            bottom: 12,
                                                            left: 24,
                                                            right: 24,
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
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (championSongs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: FloatingActionButton.extended(
                onPressed: deleteAllChampionSongs,
                icon: Icon(Icons.delete_sweep, color: colorScheme.onError),
                label: Text(
                  loc.translate('delete_all'),
                  style: TextStyle(
                    color: colorScheme.onError,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: colorScheme.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            )
          else
            const SizedBox(width: 32),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: FloatingActionButton.extended(
              onPressed: () {
                if (spotifyConnected) {
                  showDialog(
                    context: context,
                    builder: (context) => AddChampionDialog(
                      champions: _allChampions,
                      onAdd: addChampionSong,
                      spotifyService: spotifyService,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.translate("connectToSpotify"))),
                  );
                }
              },
              icon: Icon(Icons.add, color: colorScheme.onPrimary),
              label: Text(
                loc.translate('add_champion'),
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    riotService.disconnect();
    _monitor.stopMonitoring();
    super.dispose();
  }
}
