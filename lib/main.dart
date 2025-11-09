import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load the saved locale before running the app
  final prefs = await SharedPreferences.getInstance();
  final locale = prefs.getString('locale') ?? 'en';

  runApp(LoLSpotifyApp(locale: locale));
}
