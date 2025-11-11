import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SpotifyService {
  static const String clientId = '7cc258314e8f418aa792dd85d7a1ba69';
  static const String clientSecret = 'f3aac8ba753f410eb076ccab60b2b4c6';
  static const String redirectUri = 'http://localhost:8888/callback';
  static const String _tokenUrl = 'https://accounts.spotify.com/api/token';

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

  Future<Map<String, String>?> getTrackDetails(String trackId) async {
    if (!isConnected) {
      return null;
    }

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

  Future<bool> playSong(String spotifyId) async {
    if (!isConnected) return false;
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
