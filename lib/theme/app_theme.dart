import 'package:flutter/material.dart';

class AppTheme {
  // Dark Theme Colors
  static const Color black = Color(0xFF000000);
  static const Color blue = Color(0xFF4A90E2);
  static const Color yellow = Color(0xFFFFD700);
  static const Color darkGray = Color(0xFF1A1A1A);
  static const Color mediumGray = Color(0xFF2A2A2A);
  static const Color lightGray = Color(0xFF3A3A3A);
  static const Color white = Color(0xFFFFFFFF);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const Color lightText = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF666666);
  static const Color orange =
      Color(0xFFFF9500); // Replaces yellow in light mode

  // Helper to get accent color based on brightness
  static Color accentColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? yellow : orange;
  }

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
        error: Colors.red,
        onPrimary: white,
        onSecondary: black,
        onSurface: white,
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
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return blue;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(yellow),
        side: const BorderSide(color: blue, width: 2),
      ),

      // Radio theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return blue;
          }
          return white.withOpacity(0.5);
        }),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return yellow;
          }
          return white.withOpacity(0.5);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
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

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: blue,
      scaffoldBackgroundColor: lightBackground,
      cardColor: lightCard,
      dividerColor: lightBorder,

      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: blue,
        secondary: orange,
        surface: lightSurface,
        error: Colors.red,
        onPrimary: white,
        onSecondary: white,
        onSurface: lightText,
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: blue),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: lightBorder, width: 1),
        ),
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            color: lightText, fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(
            color: lightText, fontSize: 28, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(
            color: lightText, fontSize: 24, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(
            color: lightText, fontSize: 20, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            color: lightText, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: lightText, fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: lightText, fontSize: 16),
        bodyMedium: TextStyle(color: lightText, fontSize: 14),
        labelLarge: TextStyle(
            color: lightText, fontSize: 14, fontWeight: FontWeight.w500),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: blue, width: 2),
        ),
        labelStyle: const TextStyle(color: lightTextSecondary),
        hintStyle: TextStyle(color: lightTextSecondary.withOpacity(0.7)),
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
          elevation: 2,
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: blue,
        foregroundColor: white,
        elevation: 4,
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: blue,
        size: 24,
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: blue,
        unselectedItemColor: lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        titleTextStyle: const TextStyle(
          color: lightText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: lightText,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: lightBorder),
        ),
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return blue;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(white),
        side: const BorderSide(color: blue, width: 2),
      ),

      // Radio theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return blue;
          }
          return lightTextSecondary;
        }),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return blue;
          }
          return lightTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return blue.withOpacity(0.5);
          }
          return lightBorder;
        }),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
