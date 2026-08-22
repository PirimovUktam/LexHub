import 'package:flutter/material.dart';

/// App-wide Design Tokens and Color Palette tailored for a trustworthy, Clean-Tech legal app
class AppColors {
  AppColors._();

  // Primary Trust - Deep Navy
  static const Color primary = Color(0xFF0F172A); // Slate 900
  static const Color primaryDark = Color(0xFF0A192F); // Deepest Navy
  static const Color primaryLight = Color(0xFF1E293B); // Slate 800
  static const Color primaryContainer = Color(0xFF334155);

  // Royal Indigo - User Summary & Highlights
  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoLight = Color(0xFFEEF2FF);
  static const Color indigoDark = Color(0xFF4F46E5);

  // Emerald Green - Verified Legal Grounding & Low Risk
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFFD1FAE5);
  static const Color emeraldDark = Color(0xFF059669);
  static const Color riskLow = Color(0xFF10B981);
  static const Color riskLowBg = Color(0xFFD1FAE5);

  // Amber Warning - Medium Risk & Cautions
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFEF3C7);
  static const Color amberDark = Color(0xFFD97706);
  static const Color riskMedium = Color(0xFFF59E0B);
  static const Color riskMediumBg = Color(0xFFFEF3C7);

  // Crimson Red - Emergency Red Flags & High Risk
  static const Color crimson = Color(0xFFEF4444);
  static const Color crimsonLight = Color(0xFFFEE2E2);
  static const Color crimsonDark = Color(0xFFDC2626);
  static const Color crimsonDarkBg = Color(0xFF2D1518);
  static const Color emergency = Color(0xFFEF4444);
  static const Color emergencyLight = Color(0xFFFEE2E2);
  static const Color emergencyDark = Color(0xFFF87171); // Light crimson for dark mode
  static const Color emergencyBorder = Color(0xFFFCA5A5);
  static const Color riskHigh = Color(0xFFEF4444);
  static const Color riskHighBg = Color(0xFFFEE2E2);
  static const Color riskCritical = Color(0xFF9333EA); // Purple critical
  static const Color riskCriticalBg = Color(0xFFF3E8FF);
  static const Color riskCriticalDark = Color(0xFFC084FC); // Light purple for dark mode

  // Lex.uz Credibility Blue
  static const Color lexBlue = Color(0xFF0284C7);
  static const Color lexBlueLight = Color(0xFFE0F2FE);
  static const Color lexBlueDark = Color(0xFF0369A1);

  // Regal Gold / Accent
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentDark = Color(0xFFD97706);

  // Neutral Light
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFF1F5F9);

  // Neutral Dark
  static const Color backgroundDark = Color(0xFF0A192F);
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1); // Slate 300 - High Contrast
  static const Color textMutedDark = Color(0xFF94A3B8); // Slate 400 - Clear Readable
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF1E293B);

  // Dark Alert & Badge Backgrounds
  static const Color emergencyDarkBg = Color(0xFF2D1518);
  static const Color emergencyDarkBorder = Color(0xFF5C2329);
  static const Color emeraldDarkBg = Color(0xFF0D281E);
  static const Color emeraldDarkBorder = Color(0xFF165B40);
  static const Color amberDarkBg = Color(0xFF2C2009);
  static const Color amberDarkBorder = Color(0xFF6B4D0E);
  static const Color lexBlueDarkBg = Color(0xFF0C243C);
  static const Color lexBlueDarkBorder = Color(0xFF134E7B);
  static const Color indigoDarkBg = Color(0xFF1E1B4B);
  static const Color indigoDarkBorder = Color(0xFF3730A3);
}
