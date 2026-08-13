import 'package:flutter/material.dart';

import '../models/models.dart';

class AppColors {
  static const bg = Color(0xFF060B14);
  static const panel = Color(0xFF0F172A);
  static const panelLight = Color(0xFF162033);
  static const border = Color(0xFF243047);
  static const lcdesign = Color(0xFF2563EB);
  static const intervereda = Color(0xFF059669);
  static const amber = Color(0xFFF59E0B);
  static const text = Color(0xFFE2E8F0);
  static const muted = Color(0xFF94A3B8);
}

class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.lcdesign,
        secondary: AppColors.intervereda,
        surface: AppColors.panel,
        onSurface: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xCC080D18),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
      ),
      cardTheme: CardTheme(
        color: AppColors.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF020617),
        labelStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.lcdesign, width: 1.4)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lcdesign,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.panelLight,
        selectedColor: AppColors.lcdesign.withOpacity(0.25),
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(color: AppColors.text),
      ),
      useMaterial3: true,
    );
  }
}

Color parseHexColor(String hex) {
  final value = hex.replaceAll('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

String priorityLabel(String priority) {
  switch (priority) {
    case 'low':
      return 'Baja';
    case 'high':
      return 'Alta';
    case 'urgent':
      return 'Urgente';
    default:
      return 'Media';
  }
}

Color priorityColor(String priority) {
  switch (priority) {
    case 'low':
      return AppColors.muted;
    case 'high':
      return AppColors.amber;
    case 'urgent':
      return Colors.redAccent;
    default:
      return AppColors.lcdesign;
  }
}

String timeUntil(DateTime date) {
  final diff = date.difference(DateTime.now());
  if (diff.isNegative) return 'Ahora';
  if (diff.inMinutes < 60) return 'En ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'En ${diff.inHours} h';
  return 'En ${diff.inDays} d';
}

String statusLabel(String status) {
  switch (status) {
    case 'in_progress':
      return 'En curso';
    case 'completed':
      return 'Completado';
    case 'cancelled':
      return 'Cancelado';
    default:
      return 'Programado';
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'in_progress':
      return AppColors.intervereda;
    case 'completed':
      return AppColors.muted;
    case 'cancelled':
      return Colors.redAccent;
    default:
      return AppColors.lcdesign;
  }
}

String commitmentBadge(Commitment event) {
  if (event.status == 'in_progress') return 'En curso';
  if (event.status == 'completed') return 'Completado';
  if (event.status == 'cancelled') return 'Cancelado';

  final now = DateTime.now();
  if (now.isAfter(event.startsAt) && now.isBefore(event.endsAt)) {
    return '¡Ahora!';
  }
  return timeUntil(event.startsAt);
}

Color commitmentBadgeColor(Commitment event) {
  if (event.status == 'in_progress') return AppColors.intervereda;
  if (event.status == 'completed') return AppColors.muted;

  final now = DateTime.now();
  if (now.isAfter(event.startsAt) && now.isBefore(event.endsAt)) {
    return AppColors.amber;
  }
  return AppColors.lcdesign;
}
