import 'package:flutter/material.dart';

class AppColors {
  // Prevent instantiation
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFFF3F7F5);
  static const Color cardBackground = Colors.white;
  static const Color searchBackground = Colors.white;

  // Primary & Accent Colors
  static const Color primaryPink = Color(0xFFFA4A6F);
  static const Color primaryPinkHover = Color(0xFFE83B5E);
  static const Color editGreen = Color(0xFF80BC24);
  static const Color editGreenDark = Color(0xFF6EA31E);

  // Delete Button & Badges
  static const Color deleteBg = Color(0xFFFDE8EC);
  static const Color deleteIcon = Color(0xFFFA4A6F);

  // Typography Colors
  static const Color textDark = Color(0xFF2C3238);
  static const Color textMuted = Color(0xFF8E959E);
  static const Color textPrice = Color(0xFFFA4A6F);

  // Bottom Navigation Bar
  static const Color navBarBg = Colors.white;
  static const Color navInactive = Color(0xFFAAB2BA);
  static const Color navActive = Color(0xFFFA4A6F);

  // Borders & Shadows
  static const Color inputBorder = Color(0xFFE8ECEF);
  static Color cardShadow = const Color(0xFF1E2833).withValues(alpha: 0.06);
}
