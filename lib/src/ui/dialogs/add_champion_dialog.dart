import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lol_spotify_companion/src/services/spotify_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/champion.dart';
import '../../models/champion_song.dart';
import '../widgets/champion_list_item.dart';

class AddChampionDialog extends StatefulWidget {
  final Function(ChampionSong) onAdd;
  final List<Champion> champions;
  final SpotifyService spotifyService;

  const AddChampionDialog({
    super.key,
    required this.onAdd,
    required this.champions,
    required this.spotifyService,
  });

  @override
  State<AddChampionDialog> createState() => _AddChampionDialogState();
}

class _AddChampionDialogState extends State<AddChampionDialog> {
  List<Champion> filteredChampions = [];
  Champion? selectedChampion;
  final TextEditingController championController = TextEditingController();
  final TextEditingController spotifyController = TextEditingController();
  final TextEditingController songController = TextEditingController();
  final TextEditingController artistController = TextEditingController();
  final FocusNode championFocus = FocusNode();
  bool showDropdown = false;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Timer? _debounce;
  bool _isFetchingSong = false;

  @override
  void initState() {
    super.initState();
    filteredChampions = widget.champions;
    championController.addListener(_filterChampions);
    spotifyController.addListener(_onSpotifyIdChanged);
  }

  void _onSpotifyIdChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 750), () {
      _fetchTrackDetails();
    });
  }

  Future<void> _fetchTrackDetails() async {
    String text = spotifyController.text.trim();
    final loc = AppLocalizations.of(context);
    if (text.isEmpty) {
      setState(() {
        songController.text = '';
        artistController.text = '';
      });
      return;
    }
    String? trackId;
    try {
      final uri = Uri.parse(text);
      if (uri.host.contains('spotify.com')) {
        final trackIndex = uri.pathSegments.indexOf('track');
        if (trackIndex != -1 && uri.pathSegments.length > trackIndex + 1) {
          trackId = uri.pathSegments[trackIndex + 1];
        }
      }
    } catch (_) {}

    trackId ??= text;

    setState(() {
      _isFetchingSong = true;
      songController.text = '...';
      artistController.text = '...';
    });

    final details = await widget.spotifyService.getTrackDetails(trackId);

    if (mounted) {
      setState(() {
        if (details != null) {
          songController.text = details['songName'] ?? '';
          artistController.text = details['artistName'] ?? '';
        } else {
          songController.text = '';
          artistController.text = '';
          _scaffoldMessengerKey.currentState?.clearSnackBars();
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(loc.translate('invalid_spotify_id')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        _isFetchingSong = false;
      });
    }
  }

  void _filterChampions() {
    setState(() {
      if (championController.text.isEmpty) {
        filteredChampions = widget.champions;
        showDropdown = false;
        selectedChampion = null;
      } else {
        filteredChampions = widget.champions
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 500,
        height: 530,
        child: ScaffoldMessenger(
          key: _scaffoldMessengerKey,
          child: Builder(
            builder: (BuildContext dialogContext) {
              return Scaffold(
                backgroundColor: theme.dialogTheme.backgroundColor,
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          loc.translate('add_champion_song'),
                          style: theme.dialogTheme.titleTextStyle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        loc.translate('champion'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (selectedChampion != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.asset(
                                  selectedChampion!.imagePath,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 40,
                                        height: 40,
                                        color: colorScheme.primary,
                                        child: Center(
                                          child: Text(
                                            selectedChampion!.name[0]
                                                .toUpperCase(),
                                            style: TextStyle(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: TextField(
                              controller: championController,
                              focusNode: championFocus,
                              style: TextStyle(color: colorScheme.onSurface),
                              decoration: InputDecoration(
                                hintText: loc.translate(
                                  'search_select_champion',
                                ),
                                prefixIcon: selectedChampion == null
                                    ? Icon(
                                        Icons.search,
                                        color: colorScheme.primary,
                                      )
                                    : null,
                              ),
                              onTap: () {
                                setState(() {
                                  showDropdown = true;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (showDropdown && filteredChampions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: colorScheme.outline),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: spotifyController,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'e.g., 3n3Ppam7vgaVa1iaRUc9Lp',
                          suffixIcon: _isFetchingSong
                              ? Container(
                                  padding: const EdgeInsets.all(12.0),
                                  child: const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('song_name'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: songController,
                        enabled: false,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Schnapp!',
                          suffixIcon: _isFetchingSong
                              ? Container(
                                  padding: const EdgeInsets.all(12.0),
                                  child: const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('artist_name'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: artistController,
                        enabled: false,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Gzuz',
                          suffixIcon: _isFetchingSong
                              ? Container(
                                  padding: const EdgeInsets.all(12.0),
                                  child: const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.only(
                                bottom: 12,
                                left: 24,
                                right: 24,
                              ),
                            ),
                            child: Text(loc.translate('cancel')),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(
                                Theme.of(context).colorScheme.primary,
                              ),
                              foregroundColor: WidgetStateProperty.all(
                                colorScheme.onPrimary,
                              ),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.only(
                                  bottom: 10,
                                  left: 24,
                                  right: 24,
                                ),
                              ),
                            ),
                            onPressed: () {
                              if (selectedChampion == null) {
                                _scaffoldMessengerKey.currentState
                                    ?.clearSnackBars();
                                _scaffoldMessengerKey.currentState
                                    ?.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          loc.translate(
                                            'please_select_valid_champion',
                                          ),
                                        ),
                                        backgroundColor: colorScheme.error,
                                      ),
                                    );
                                return;
                              }

                              if (spotifyController.text.isEmpty ||
                                  songController.text.isEmpty ||
                                  artistController.text.isEmpty) {
                                _scaffoldMessengerKey.currentState
                                    ?.clearSnackBars();
                                _scaffoldMessengerKey.currentState
                                    ?.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          loc.translate(
                                            'please_insert_spotify_song_id',
                                          ),
                                        ),
                                        backgroundColor: colorScheme.error,
                                      ),
                                    );
                                return;
                              }

                              if (spotifyController.text.isNotEmpty &&
                                  songController.text.isEmpty) {
                                _scaffoldMessengerKey.currentState
                                    ?.clearSnackBars();
                                _scaffoldMessengerKey.currentState?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      loc.translate(
                                        'please_insert_valid_spotify_song_id',
                                      ),
                                    ),
                                    backgroundColor: colorScheme.error,
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
                                  imagePath: selectedChampion!.imagePath,
                                ),
                              );

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc.translate('song_added_success'),
                                  ),
                                  backgroundColor: colorScheme.primary,
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
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    spotifyController.removeListener(_onSpotifyIdChanged);
    championController.dispose();
    spotifyController.dispose();
    songController.dispose();
    artistController.dispose();
    championFocus.dispose();
    super.dispose();
  }
}
