import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class SpotifyService {
  static String get clientId => dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  static String get clientSecret => dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? '';
  static String get redirectUri => dotenv.env['SPOTIFY_REDIRECT_URI'] ?? '';
  static String get _tokenUrl => dotenv.env['SPOTIFY_TOKEN_URL'] ?? '';

  String? accessToken;
  String? refreshToken;
  DateTime? tokenExpiry;

  bool get isConnected => accessToken != null && refreshToken != null;

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

  Future<bool> refreshAccessToken() async {
    if (refreshToken == null) return false;

    try {
      final String credentials = '$clientId:$clientSecret';
      final String encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {
          'Authorization': 'Basic $encodedCredentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String newAccessToken = data['access_token'];
        final String? newRefreshToken = data['refresh_token'];
        final int expiresIn = data['expires_in'];

        await saveTokens(
          newAccessToken,
          newRefreshToken ?? refreshToken,
          expiresIn,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> ensureValidToken() async {
    // If no tokens at all, need to authenticate
    if (accessToken == null || refreshToken == null) {
      return false;
    }

    // If token is still valid, we're good
    if (tokenExpiry != null && tokenExpiry!.isAfter(DateTime.now())) {
      return true;
    }

    // Token expired, try to refresh
    return await refreshAccessToken();
  }

  Future<Map<String, String>?> getTrackDetails(String trackId) async {
    if (!await ensureValidToken()) return null;

    final String trackUrl = 'https://api.spotify.com/v1/tracks/$trackId';

    try {
      final response = await http.get(
        Uri.parse(trackUrl),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        final String songName = data['name'] ?? 'Unknown Song';

        final List<dynamic> artists = data['artists'] ?? [];
        final String artistName = artists
            .map((artist) => artist['name'] as String? ?? 'Unknown Artist')
            .join(', ');

        return {
          'songName': songName,
          'artistName': artistName.isEmpty ? 'Unknown Artist' : artistName,
        };
      } else {
        return null;
      }
    } catch (e) {
      return null;
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

  Future<bool> isCurrentlyPlaying() async {
    if (!await ensureValidToken()) return false;

    try {
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['is_playing'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> playSong(String spotifyId) async {
    if (!await ensureValidToken()) return false;
    final isPlaying = await isCurrentlyPlaying();
    if (!isPlaying) {
      return false;
    }
    if (spotifyId.contains("/")) {
      spotifyId = spotifyId.substring(spotifyId.lastIndexOf("/") + 1);
    }
    if (spotifyId.contains("?")) {
      spotifyId = spotifyId.split("?")[0];
    }
    try {
      final playResponse = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/play'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'uris': ['spotify:track:$spotifyId'],
        }),
      );
      if (playResponse.statusCode != 204 && playResponse.statusCode != 200) {
        return false;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      final repeatResponse = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/repeat?state=track'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      return playResponse.statusCode == 204 || playResponse.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> exchangeCodeForToken(String code) async {
    try {
      final String credentials = '$clientId:$clientSecret';
      final String encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {
          'Authorization': 'Basic $encodedCredentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String accessToken = data['access_token'];
        final String? refreshToken = data['refresh_token'];
        final int expiresIn = data['expires_in'];

        await saveTokens(accessToken, refreshToken, expiresIn);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
