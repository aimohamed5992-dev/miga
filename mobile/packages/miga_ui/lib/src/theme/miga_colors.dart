import 'package:flutter/material.dart';

/// MIGA brand palette — primary red sampled from the logo (#C4011A).
class MigaColors {
  MigaColors._();

  // Brand
  static const primary = Color(0xFFC4011A);
  static const primaryDark = Color(0xFF8E0013);
  static const primaryLight = Color(0xFFE8334A);
  static const primarySoft = Color(0xFFFDECEE);
  static const primaryGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFE0102C), primary, primaryDark],
  );

  // Neutrals
  static const ink = Color(0xFF16161A);
  static const textPrimary = Color(0xFF1C1C21);
  static const textSecondary = Color(0xFF6B6B78);
  static const textHint = Color(0xFFA3A3AF);
  static const border = Color(0xFFEBEBF0);
  static const divider = Color(0xFFF1F1F5);
  static const background = Color(0xFFF7F7F9);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF2F2F5);

  // Semantic
  static const success = Color(0xFF12A15E);
  static const successSoft = Color(0xFFE7F7EF);
  static const warning = Color(0xFFF08C00);
  static const warningSoft = Color(0xFFFFF4E0);
  static const info = Color(0xFF2E7CF6);
  static const infoSoft = Color(0xFFE9F1FF);
  static const error = Color(0xFFD92D20);
  static const errorSoft = Color(0xFFFDECEA);
  static const gold = Color(0xFFF5B000);

  // Role accents — each app keeps the brand red but has its own secondary tone.
  static const merchantAccent = Color(0xFF1F2A44);
  static const driverAccent = Color(0xFF0F766E);

  /// Data-mark variant of the driver teal (validated: the darker accent reads gray in charts).
  static const driverChart = Color(0xFF14958B);
}
