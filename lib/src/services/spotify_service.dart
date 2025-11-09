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
      print('Not connected, cannot fetch track details.');
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

        // Get song name
        final String songName = data['name'] ?? 'Unknown Song';

        // Get artist(s)
        final List<dynamic> artists = data['artists'] ?? [];
        final String artistName = artists
            .map((artist) => artist['name'] as String? ?? 'Unknown Artist')
            .join(', '); // Join multiple artists with a comma

        return {
          'songName': songName,
          'artistName': artistName.isEmpty ? 'Unknown Artist' : artistName,
        };
      } else {
        print('Failed to get track details: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching track details: $e');
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

    try {
      final response = await http.put(
        // This is still a placeholder URL. You'll need the real Spotify API URL for playback.
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

  // This exchanges the code from the redirect for an access token
  Future<bool> exchangeCodeForToken(String code) async {
    try {
      // Create the authorization header (Basic Auth)
      final String credentials = '$clientId:$clientSecret';
      final String encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await http.post(
        Uri.parse(_tokenUrl), // Now uses the correct URL
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

        // Save the tokens
        await saveTokens(accessToken, refreshToken, expiresIn);
        return true;
      } else {
        // This print will now give a more useful error from Spotify
        print('Failed to exchange token: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error exchanging code: $e');
      return false;
    }
  }
}
