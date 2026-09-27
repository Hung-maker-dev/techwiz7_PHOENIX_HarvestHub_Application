import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme.dart';

/// Thẻ dùng chung: viền 1px `border`, bo `radiusCard`, không đổ bóng mặc định.
/// [interactive] = true thêm hiệu ứng viền màu primary khi nhấn-giữ.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.interactive = false,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.space2),
  });

  final Widget child;
  final bool interactive;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.interactive && _pressed ? AppColors.primary : AppColors.border;

    final card = AnimatedContainer(
      duration: AppDurations.micro,
      curve: AppCurves.easeOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: widget.child,
    );

    if (!widget.interactive) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: widget.onTap,
      onHighlightChanged: (v) => setState(() => _pressed = v),
      child: card,
    );
  }
}
