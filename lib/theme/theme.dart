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
        iconTheme: IconThemeData(
          color: FAColors.primaryTextColor,
        ),
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
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: FAColors.faAccentColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: FAColors.faAccentColor, width: 2),
        ),
        hintStyle: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
        prefixIconColor: FAColors.faAccentColor,
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
        selectedItemColor: FAColors.faAccentColor,
        unselectedItemColor: Colors.grey[360],
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
        ),
      ),

      // Checkbox 테마 추가
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return FAColors.faAccentColor; // 체크됐을 때 색상
          }
          return Colors.white; // 체크 안됐을 때 색상을 흰색으로 변경
        }),
        checkColor: WidgetStateProperty.all(Colors.white), // 체크마크 색상
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // 체크박스 모서리 둥글게
        ),
        // 테두리 색상 설정
        side: const BorderSide(color: FAColors.faAccentColor), // 테두리 색상 추가
      ),

      // Icon theme 추가
      iconTheme: const IconThemeData(
        color: FAColors.faAccentColor, // 기본 아이콘 색상
        size: 24, // 기본 아이콘 크기
      ),
    );
  }
}
