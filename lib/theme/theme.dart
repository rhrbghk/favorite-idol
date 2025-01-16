import 'package:flutter/material.dart';
import 'package:favorite_idol/theme/colors.dart';

class FATheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: FAColors.faAccentColor,
        brightness: Brightness.light,
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: FAColors.backgroundColor,
        foregroundColor: FAColors.primaryTextColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      // Scaffold background color
      scaffoldBackgroundColor: FAColors.backgroundColor,

      // Text theme
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: FAColors.primaryTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          color: FAColors.primaryTextColor,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: FAColors.primaryTextColor,
          fontSize: 14,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FAColors.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FAColors.faAccentColor),
        ),
      ),

      // Button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FAColors.faAccentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // BottomNavigationBar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: const Color(0xFFff9ed6),
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
        ),
      ),
    );
  }
}
