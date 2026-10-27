import 'package:flutter/material.dart';

class AppColors {
  // Primary / Brand colors
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color secondary = Color(0xFF6366F1); // Indigo 500
  static const Color primaryLight = Color(0xFFEEF2F6); // Very light indigo

  // Status colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444); // Rose
  static const Color error = danger; // Alias for danger
  static const Color info = Color(0xFF3B82F6); // Blue

  // Neutral colors (slate palette)
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);

  // Background colors
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = bgLight;

  // Text aliases
  static const Color textPrimary = slate900;
  static const Color textSecondary = slate500;
}
