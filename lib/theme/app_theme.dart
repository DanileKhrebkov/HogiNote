import 'package:flutter/material.dart';

/// Тёмная тема в около-бежевых тонах.
const Color bgDark = Color(0xFF1A1815);
const Color bgCard = Color(0xFF24211D);
const Color accentBeige = Color(0xFFD4C4A8);
const Color textPrimary = Color(0xFFEDE8E0);
const Color textSecondary = Color(0xFFA89F94);

const double cardRadius = 12;

ThemeData buildHoginoteTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: accentBeige,
      onPrimary: bgDark,
      surface: bgCard,
      onSurface: textPrimary,
      secondary: accentBeige,
      error: Colors.redAccent,
    ),
    scaffoldBackgroundColor: bgDark,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: textSecondary,
      textColor: textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: bgCard,
      selectedItemColor: accentBeige,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: bgCard,
      selectedIconTheme: IconThemeData(color: accentBeige),
      unselectedIconTheme: IconThemeData(color: textSecondary),
      selectedLabelTextStyle: TextStyle(color: accentBeige),
      unselectedLabelTextStyle: TextStyle(color: textSecondary),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentBeige,
      foregroundColor: bgDark,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accentBeige,
      inactiveTrackColor: textSecondary.withOpacity(0.3),
      thumbColor: accentBeige,
      overlayColor: accentBeige.withOpacity(0.15),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: bgCard,
      contentTextStyle: TextStyle(color: textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgCard,
      hintStyle: const TextStyle(color: textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        borderSide: BorderSide.none,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: accentBeige,
      unselectedLabelColor: textSecondary,
      indicatorColor: accentBeige,
    ),
    dividerColor: textSecondary.withOpacity(0.2),
  );
}
