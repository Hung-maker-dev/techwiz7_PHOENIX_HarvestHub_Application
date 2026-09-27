// lib/features/admin/widgets/stat_card.dart
//
// Dùng ở Dashboard (4.1) và Reports (4.9). Count-up theo pattern #8
// (ANIMATION_SYSTEM_MOBILE.md): TweenAnimationBuilder<double>(0 → giá trị
// thật), AppDurations.emphasis + AppCurves.easeOut, chạy đúng 1 lần khi data
// vừa tải xong. `_hasAnimated` dùng ValueKey theo `value` ở nơi gọi để reset
// khi provider trả dữ liệu mới (vd đổi period ở Reports) — StatCard tự nó
// luôn tween từ 0 mỗi khi được build mới với key khác, không tự lặp khi
// rebuild cùng giá trị nhờ `TweenAnimationBuilder` chỉ animate khi tween
// thay đổi.

import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueFormatter,
    this.color,
  });

  final String label;
  final double value;
  final IconData? icon;
  final String Function(double)? valueFormatter;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, size: 18, color: accent),
              if (icon != null) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: reduceMotion ? Duration.zero : AppDurations.emphasis,
            curve: AppCurves.easeOut,
            builder: (context, animatedValue, _) => Text(
              valueFormatter?.call(animatedValue) ??
                  animatedValue.toStringAsFixed(0),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
