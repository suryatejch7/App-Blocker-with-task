import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color black = Color(0xFF000000);
  static const Color blue = Color(0xFF4A90E2);
  static const Color yellow = Color(0xFFFFD700);
  static const Color darkGray = Color(0xFF1A1A1A);
  static const Color mediumGray = Color(0xFF2A2A2A);
  static const Color lightGray = Color(0xFF3A3A3A);
  static const Color white = Color(0xFFFFFFFF);

  // Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: blue,
      scaffoldBackgroundColor: black,
      cardColor: darkGray,
      dividerColor: lightGray,

      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: blue,
        secondary: yellow,
        surface: darkGray,
        background: black,
        error: Colors.red,
        onPrimary: white,
        onSecondary: black,
        onSurface: white,
        onBackground: white,
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        foregroundColor: white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: yellow),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: darkGray,
        elevation: 4,
        shadowColor: blue.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: blue.withOpacity(0.3), width: 1),
        ),
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(color: white, fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium:
            TextStyle(color: white, fontSize: 28, fontWeight: FontWeight.bold),
        displaySmall:
            TextStyle(color: white, fontSize: 24, fontWeight: FontWeight.bold),
        headlineMedium:
            TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.w600),
        titleLarge:
            TextStyle(color: white, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium:
            TextStyle(color: white, fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: white, fontSize: 16),
        bodyMedium: TextStyle(color: white, fontSize: 14),
        labelLarge:
            TextStyle(color: white, fontSize: 14, fontWeight: FontWeight.w500),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: mediumGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: blue.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: blue.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: blue, width: 2),
        ),
        labelStyle: const TextStyle(color: white),
        hintStyle: TextStyle(color: white.withOpacity(0.5)),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 4,
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: yellow,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: yellow,
        foregroundColor: black,
        elevation: 6,
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: yellow,
        size: 24,
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkGray,
        selectedItemColor: yellow,
        unselectedItemColor: white.withOpacity(0.6),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: darkGray,
        titleTextStyle: const TextStyle(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: white,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: blue.withOpacity(0.5)),
        ),
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return blue;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(yellow),
        side: const BorderSide(color: blue, width: 2),
      ),

      // Radio theme
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return blue;
          }
          return white.withOpacity(0.5);
        }),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return yellow;
          }
          return white.withOpacity(0.5);
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return blue;
          }
          return lightGray;
        }),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: lightGray,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
