import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { sm, md, lg }

/// Nút dùng chung toàn app. Khi [loading] = true: chữ vẫn hiện, icon được
/// thay bằng CircularProgressIndicator nhỏ, và onPressed tự vô hiệu hoá
/// để chống double-submit (không cần feature code tự quản lý cờ này).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final IconData? icon;

  double get _height => switch (size) {
        AppButtonSize.sm => 36,
        AppButtonSize.md => 44,
        AppButtonSize.lg => 52,
      };

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final colors = _colorsFor(variant);

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: colors.fg),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: colors.fg),
        if (loading || icon != null) const SizedBox(width: 8),
        Text(label, style: TextStyle(color: colors.fg, fontWeight: FontWeight.w600)),
      ],
    );

    return SizedBox(
      height: _height,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.bg,
          disabledBackgroundColor: colors.bg.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            side: colors.border != null ? BorderSide(color: colors.border!) : BorderSide.none,
          ),
        ),
        child: child,
      ),
    );
  }

  _ButtonColors _colorsFor(AppButtonVariant v) {
    switch (v) {
      case AppButtonVariant.primary:
        return _ButtonColors(bg: AppColors.primary, fg: Colors.white);
      case AppButtonVariant.secondary:
        return _ButtonColors(bg: AppColors.surface, fg: AppColors.text, border: AppColors.border);
      case AppButtonVariant.ghost:
        return _ButtonColors(bg: Colors.transparent, fg: AppColors.primary);
      case AppButtonVariant.danger:
        return _ButtonColors(bg: AppColors.danger, fg: Colors.white);
    }
  }
}

class _ButtonColors {
  _ButtonColors({required this.bg, required this.fg, this.border});
  final Color bg;
  final Color fg;
  final Color? border;
}
