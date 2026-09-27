import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 1.4 Giới thiệu — route `/about`. Nội dung tĩnh, không API,
/// không animation đặc biệt.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('common.about.title'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.space3),
          child: Text(
            'common.about.body'.tr(),
            style: const TextStyle(fontSize: 15, height: 1.6, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}
