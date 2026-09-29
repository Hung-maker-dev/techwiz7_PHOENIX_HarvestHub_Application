import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

enum AppModalSize { sm, md, lg }

class AppModal {
  AppModal._();

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    AppModalSize size = AppModalSize.md,
    List<Widget>? actions,
  }) {
    final width = switch (size) {
      AppModalSize.sm => 320.0,
      AppModalSize.md => 420.0,
      AppModalSize.lg => 560.0,
    };

    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.space2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.space1),
                content,
                if (actions != null) ...[
                  const SizedBox(height: AppSpace.space2),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
