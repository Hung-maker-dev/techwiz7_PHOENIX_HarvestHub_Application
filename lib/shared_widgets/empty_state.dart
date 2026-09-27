import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.icon = Icons.inbox_outlined,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData icon;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: AppSpace.space2),
          Text(
            title,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpace.space1),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpace.space2),
            AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.primary),
          ],
        ],
      ),
    );
  }
}
