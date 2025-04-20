import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
    primaryColor: Colors.blue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      secondary: Colors.amber,
    ),
    cardTheme: CardTheme(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.15,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        letterSpacing: 0.5,
      ),
    ),
  );
}
