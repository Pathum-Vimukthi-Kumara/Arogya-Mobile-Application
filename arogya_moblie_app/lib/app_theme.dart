import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── Brand colours ──────────────────────────────────────────────────
  static const Color primary     = Color(0xFF38A3A5);
  static const Color primaryLight = Color(0xFFE0F4F4);
  static const Color primaryDark  = Color(0xFF2A7D7F);

  static const Color background  = Color(0xFFF3F4F6); // gray-100
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color border      = Color(0xFFE5E7EB); // gray-200

  static const Color textPrimary   = Color(0xFF111827); // gray-900
  static const Color textSecondary = Color(0xFF6B7280); // gray-500
  static const Color textHint      = Color(0xFF9CA3AF); // gray-400

  static const Color error   = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  // ── Status bar styles ───────────────────────────────────────────────
  /// Use on teal/dark hero sections
  static const SystemUiOverlayStyle overlayLight = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  /// Use on white/light sections
  static const SystemUiOverlayStyle overlayDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  // ── Theme ───────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          onPrimary: Colors.white,
          surface: surface,
        ),
        scaffoldBackgroundColor: background,

        // AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          shadowColor: border,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),

        // Input fields
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: background,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: error, width: 1.8),
          ),
          hintStyle: const TextStyle(color: textHint, fontSize: 14),
          labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
          errorStyle: const TextStyle(fontSize: 12),
        ),

        // Elevated button
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Color(0xFFB0D8D9),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),

        // Text button
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primary),
        ),

        // Outlined button
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: error,
            side: const BorderSide(color: error),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),

        // Card
        cardTheme: const CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            side: BorderSide(color: border),
          ),
          margin: EdgeInsets.zero,
        ),

        // Bottom NavigationBar (Material 3)
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: primaryLight,
          indicatorShape: const CircleBorder(
          side: BorderSide(color: Colors.transparent, width: 12), // Adds padding
          ),
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shadowColor: Colors.black12,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryDark,
              );
            }
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: textSecondary,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: primaryDark, size: 24);
            }
            return const IconThemeData(color: textSecondary, size: 24);
          }),
        ),

        // Divider
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 1,
          space: 1,
        ),
      );
}
