import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectivityProvider).valueOrNull ?? true;

    return AnimatedSize(
      duration: AppDurations.standard,
      curve: AppCurves.easeOut,
      child: AnimatedOpacity(
        duration: AppDurations.standard,
        opacity: connected ? 0 : 1,
        child: connected
            ? const SizedBox(width: double.infinity, height: 0)
            : Container(
                width: double.infinity,
                height: 4,
                color: AppColors.accent,
                child: connected ? null : _label(context),
              ),
      ),
    );
  }

  Widget? _label(BuildContext context) =>
      null; // dải màu thuần theo spec, không chữ
}

class OfflineBannerWithLabel extends ConsumerWidget {
  const OfflineBannerWithLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectivityProvider).valueOrNull ?? true;

    return AnimatedSize(
      duration: AppDurations.standard,
      curve: AppCurves.easeOut,
      child: AnimatedOpacity(
        duration: AppDurations.standard,
        opacity: connected ? 0 : 1,
        child: connected
            ? const SizedBox(width: double.infinity, height: 0)
            : Container(
                width: double.infinity,
                color: AppColors.accent.withValues(alpha: 0.15),
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                child: Text(
                  'common.shared.offline'.tr(),
                  style: const TextStyle(fontSize: 12, color: AppColors.text),
                ),
              ),
      ),
    );
  }
}
