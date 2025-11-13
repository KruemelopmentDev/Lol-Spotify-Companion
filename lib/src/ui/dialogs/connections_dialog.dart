import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../services/riot_client_service.dart';
import '../../services/spotify_service.dart';

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
  bool isConnecting = false;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  bool alertErrorRiotConnection = false;

  @override
  void initState() {
    super.initState();
    widget.riotService.addListener(_onRiotConnectionChange);
  }

  @override
  void dispose() {
    widget.riotService.removeListener(_onRiotConnectionChange);
    super.dispose();
  }

  void _onRiotConnectionChange() {
    widget.onConnectionChanged();
    if (alertErrorRiotConnection && !widget.riotService.isConnected) {
      final loc = AppLocalizations.of(context);
      _scaffoldMessengerKey.currentState?.clearSnackBars();
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(loc.translate('riot_connection_error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      setState(() {
        alertErrorRiotConnection = false;
      });
    }
    setState(() {});
  }

  Future<void> _connectSpotify(BuildContext dialogContext) async {
    final loc = AppLocalizations.of(context);
    HttpServer? server;

    setState(() => isConnecting = true);

    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8888);
      final String authUrl = _getSpotifyAuthUrl();

      if (await canLaunchUrl(Uri.parse(authUrl))) {
        await launchUrl(
          Uri.parse(authUrl),
          mode: LaunchMode.externalApplication,
        );
      } else if (mounted) {
        _scaffoldMessengerKey.currentState?.clearSnackBars();
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(loc.translate('launch_error')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      await server.listen((HttpRequest request) async {
        final String? code = request.uri.queryParameters['code'];
        final String? error = request.uri.queryParameters['error'];

        if (code != null) {
          request.response
            ..headers.contentType = ContentType.html
            ..write(
              '<html><h1>${loc.translate("success")}!</h1><p>${loc.translate("spotify_page_success")}</p></html>',
            )
            ..close();
          await server?.close();

          final bool success = await widget.spotifyService.exchangeCodeForToken(
            code,
          );

          if (mounted) {
            if (success) {
              setState(() {});
              _scaffoldMessengerKey.currentState?.clearSnackBars();
              _scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(loc.translate('spotify_connected')),
                  backgroundColor: const Color(0xFF1DB954),
                ),
              );
              widget.onConnectionChanged();
            } else {
              setState(() {});
              _scaffoldMessengerKey.currentState?.clearSnackBars();
              _scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(loc.translate('token_fail')),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        } else {
          final String errorMsg = error ?? 'unknown_error';
          request.response
            ..headers.contentType = ContentType.html
            ..write(
              '<html><h1>${loc.translate("error")}: $errorMsg</h1><p>${loc.translate("spotify_page_error")}</p></html>',
            )
            ..close();
          await server?.close();

          if (mounted) {
            setState(() {});
            _scaffoldMessengerKey.currentState?.clearSnackBars();
            _scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(
                  '${loc.translate('spotify_auth_failed')}: $errorMsg',
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      }).asFuture();
    } catch (e) {
      if (mounted) {
        _scaffoldMessengerKey.currentState?.clearSnackBars();
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('${loc.translate('spotify_auth_failed')}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      await server?.close();
      if (mounted) {
        setState(() => isConnecting = false);
      }
    }
  }

  String _getSpotifyAuthUrl() {
    final clientId = SpotifyService.clientId;
    final redirectUri = SpotifyService.redirectUri;
    final scope = 'user-modify-playback-state user-read-playback-state';

    return 'https://accounts.spotify.com/authorize?'
        'client_id=$clientId&'
        'response_type=code&'
        'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
        'scope=${Uri.encodeComponent(scope)}';
  }

  Future<void> _disconnectSpotify(BuildContext dialogContext) async {
    await widget.spotifyService.disconnect();
    widget.onConnectionChanged();
    setState(() {});

    if (mounted) {
      final loc = AppLocalizations.of(context);
      _scaffoldMessengerKey.currentState?.clearSnackBars();
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(loc.translate('spotify_disconnected')),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _connectRiot(BuildContext dialogContext) async {
    setState(() {
      alertErrorRiotConnection = true;
    });
    widget.riotService.tryConnect();
  }

  Future<void> _disconnectRiot(BuildContext dialogContext) async {
    widget.riotService.disconnect();
    widget.onConnectionChanged();
    setState(() {});

    if (mounted) {
      final loc = AppLocalizations.of(context);
      final colorScheme = Theme.of(context).colorScheme;
      _scaffoldMessengerKey.currentState?.clearSnackBars();
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(loc.translate('riot_disconnected')),
          backgroundColor: colorScheme.primary,
        ),
      );
    }
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
        height: 480,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.link,
                            color: colorScheme.secondary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            loc.translate('connections'),
                            style: theme.dialogTheme.titleTextStyle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.spotifyService.isConnected
                                ? const Color(0xFF1DB954)
                                : colorScheme.outline,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spotify',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                      Text(
                                        widget.spotifyService.isConnected
                                            ? loc.translate('connected')
                                            : loc.translate('disconnected'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              widget.spotifyService.isConnected
                                              ? const Color(0xFF1DB954)
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.spotifyService.isConnected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF1DB954),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isConnecting
                                    ? null
                                    : (widget.spotifyService.isConnected
                                          ? () => _disconnectSpotify(
                                              dialogContext,
                                            )
                                          : () =>
                                                _connectSpotify(dialogContext)),
                                icon: isConnecting
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        widget.spotifyService.isConnected
                                            ? Icons.link_off
                                            : Icons.link,
                                        color: Colors.white,
                                      ),
                                label: Text(
                                  widget.spotifyService.isConnected
                                      ? loc.translate('disconnect')
                                      : (isConnecting
                                            ? loc.translate('connecting')
                                            : loc.translate('connect')),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      widget.spotifyService.isConnected
                                      ? colorScheme.error
                                      : const Color(0xFF1DB954),
                                  padding: const EdgeInsets.only(
                                    left: 24,
                                    right: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.riotService.isConnected
                                ? colorScheme.primary
                                : colorScheme.outline,
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
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.gamepad,
                                    color: colorScheme.onPrimary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loc.translate('league_client'),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                      Text(
                                        widget.riotService.isConnected
                                            ? loc.translate('connected')
                                            : loc.translate('disconnected'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: widget.riotService.isConnected
                                              ? colorScheme.primary
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.riotService.isConnected)
                                  Icon(
                                    Icons.check_circle,
                                    color: colorScheme.primary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              loc.translate('riot_instructions'),
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: widget.riotService.isConnected
                                    ? () => _disconnectRiot(dialogContext)
                                    : () => _connectRiot(dialogContext),
                                icon: Icon(
                                  widget.riotService.isConnected
                                      ? Icons.link_off
                                      : Icons.link,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  widget.riotService.isConnected
                                      ? loc.translate('disconnect')
                                      : loc.translate('connect'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      widget.riotService.isConnected
                                      ? colorScheme.error
                                      : colorScheme.primary,
                                  padding: const EdgeInsets.only(
                                    left: 24,
                                    right: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.center,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.only(
                              bottom: 12,
                              left: 24,
                              right: 24,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(loc.translate('close')),
                        ),
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
}
