import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppColors.muted)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class CompanyFilterChip extends StatelessWidget {
  const CompanyFilterChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(0.18) : AppColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color.withOpacity(0.55) : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.badge});

  final String title;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.lcdesign.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.lcdesign.withOpacity(0.25)),
            ),
            child: Text(badge!, style: const TextStyle(fontSize: 10, letterSpacing: 1, color: Color(0xFF93C5FD))),
          ),
        ],
      ],
    );
  }
}

class PdaLogo extends StatelessWidget {
  const PdaLogo({
    super.key,
    this.size = 72,
    this.variant = AppLogoVariant.compact,
  });

  final double size;
  final AppLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    return AppLogo(variant: variant, height: size);
  }
}

enum AppLogoVariant { hero, compact }

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.variant = AppLogoVariant.compact,
    this.height,
    this.width,
  });

  final AppLogoVariant variant;
  final double? height;
  final double? width;

  static const heroAsset = 'assets/images/logo_app.png';
  static const compactAsset = 'assets/images/logo_app2.png';

  String get asset => variant == AppLogoVariant.hero ? heroAsset : compactAsset;

  @override
  Widget build(BuildContext context) {
    final resolvedHeight = height ?? (variant == AppLogoVariant.hero ? 220.0 : 52.0);

    return Image.asset(
      asset,
      height: resolvedHeight,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _fallback(resolvedHeight),
    );
  }

  Widget _fallback(double h) {
    return Container(
      width: h,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(h * 0.28),
        gradient: const LinearGradient(colors: [AppColors.lcdesign, AppColors.intervereda]),
      ),
      alignment: Alignment.center,
      child: Text('PDA', style: TextStyle(fontWeight: FontWeight.w800, fontSize: h * 0.24, letterSpacing: 1.5)),
    );
  }
}
