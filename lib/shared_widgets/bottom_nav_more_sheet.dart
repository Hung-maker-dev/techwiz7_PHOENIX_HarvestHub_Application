import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'app_bottom_sheet.dart';
import 'language_switcher.dart';
import 'theme_toggle.dart';

/// Thay thế `Footer.jsx` của bản web — mobile không có khái niệm footer.
/// Mở bằng AppBottomSheet.show ở luồng khách hàng khi không cần hiện đầy đủ
/// các link phụ trên mọi màn hình.
class BottomNavMoreSheet extends StatelessWidget {
  const BottomNavMoreSheet({super.key});

  static Future<void> open(BuildContext context) {
    return AppBottomSheet.show(
      context: context,
      title: 'common.shared.more'.tr(),
      child: const BottomNavMoreSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MoreTile(
          icon: Icons.info_outline,
          label: 'common.moreSheet.about'.tr(),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/about');
          },
        ),
        _MoreTile(
          icon: Icons.mail_outline,
          label: 'common.moreSheet.contact'.tr(),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/contact');
          },
        ),
        _MoreTile(
          icon: Icons.help_outline,
          label: 'common.moreSheet.faq'.tr(),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/faq');
          },
        ),
        const Divider(height: AppSpace.space3, color: AppColors.border),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.language, color: AppColors.textSecondary),
          title: Text('common.moreSheet.language'.tr()),
          trailing: const LanguageSwitcher(),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.brightness_6_outlined, color: AppColors.textSecondary),
          title: Text('common.moreSheet.theme'.tr()),
          trailing: const ThemeToggle(),
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label),
      onTap: onTap,
    );
  }
}
