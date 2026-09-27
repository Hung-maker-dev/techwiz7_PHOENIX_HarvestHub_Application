import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

enum AppSkeletonVariant { card, row, text }

/// Skeleton loading (pattern #6) — đúng hình dạng nội dung thật.
/// CircularProgressIndicator CHỈ dùng trong nút bấm (AppButton loading=true),
/// không dùng widget này thay thế cho nút.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, this.variant = AppSkeletonVariant.row, this.count = 1});

  final AppSkeletonVariant variant;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.surface,
      child: Column(
        children: List.generate(count, (i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.space1),
              child: _shape(),
            )),
      ),
    );
  }

  Widget _shape() {
    switch (variant) {
      case AppSkeletonVariant.card:
        return Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        );
      case AppSkeletonVariant.row:
        return Row(
          children: [
            Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: AppSpace.space1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(height: 12, width: 120, color: Colors.white),
                ],
              ),
            ),
          ],
        );
      case AppSkeletonVariant.text:
        return Container(height: 14, width: double.infinity, color: Colors.white);
    }
  }
}
