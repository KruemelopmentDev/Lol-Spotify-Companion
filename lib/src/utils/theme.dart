import 'package:flutter/material.dart';

const lolColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFC89B3C),
  onPrimary: Color(0xFF010A13),
  secondary: Color(0xFFC89B3C),
  onSecondary: Color(0xFF010A13),
  tertiary: Color(0xFF785A28),
  onTertiary: Color(0xFFF0E6D2),
  error: Color(0xFFD13639),
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFF091428),
  onSurface: Color(0xFFA09B8C),
  outline: Color(0xFF1E2328),
  onSurfaceVariant: Color(0xFF5B5A56),
);

final appTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: lolColorScheme,
  primaryColor: lolColorScheme.primary,
  scaffoldBackgroundColor: lolColorScheme.background,

  cardTheme: CardThemeData(
    color: lolColorScheme.surface,
    elevation: 2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: lolColorScheme.primary,
      foregroundColor: lolColorScheme.onPrimary,
      padding: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: lolColorScheme.surface,
    hintStyle: TextStyle(color: lolColorScheme.onSurfaceVariant),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: lolColorScheme.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: lolColorScheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: lolColorScheme.primary, width: 2),
    ),
  ),

  textTheme: const TextTheme().apply(
    bodyColor: lolColorScheme.onSurface,
    displayColor: lolColorScheme.onSurface,
  ),

  appBarTheme: AppBarTheme(
    backgroundColor: lolColorScheme.surface,
    elevation: 0,
    iconTheme: IconThemeData(color: lolColorScheme.primary),
  ),

  dialogTheme: DialogThemeData(
    backgroundColor: lolColorScheme.surface,
    titleTextStyle: TextStyle(
      color: lolColorScheme.secondary,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: lolColorScheme.primary,
    contentTextStyle: TextStyle(color: lolColorScheme.onPrimary),
    actionTextColor: lolColorScheme.onPrimary,
  ),
);
