// lib/features/admin/dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../providers/admin/admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/most_active_farmers_list.dart';
import 'widgets/pending_actions_list.dart';
import 'widgets/revenue_by_market_chart.dart';
import 'widgets/stat_card.dart';
import 'admin_localization.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return AdminShell(
      currentRoute: '/admin',
      // i18n key gốc: admin.dashboard.title — thay bằng .tr() khi
      // easy_localization + l10n/vi.json,en.json đã sẵn sàng lúc merge.
      title: adminText(context, 'Bảng điều khiển'),
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardSummaryProvider),
        child: summaryAsync.when(
          loading: () => _DashboardSkeleton(),
          error: (err, _) => _ErrorState(
            onRetry: () => ref.invalidate(dashboardSummaryProvider),
          ),
          data: (summary) => ListView(
            padding: EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  StatCard(
                    label: adminText(context, 'Tổng đơn hàng'),
                    value: summary.totalOrders.toDouble(),
                    icon: Icons.receipt_long_outlined,
                  ),
                  StatCard(
                    label: adminText(context, 'Tổng doanh thu'),
                    value: summary.totalRevenue,
                    icon: Icons.payments_outlined,
                    valueFormatter: (v) => '${v.toStringAsFixed(0)}đ',
                  ),
                ],
              ),
              SizedBox(height: 24),
              Text(adminText(context, 'Doanh thu theo chợ'),
                  style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 8),
              RevenueByMarketChart(data: summary.revenueByMarket),
              SizedBox(height: 24),
              Text(adminText(context, 'Nông dân tích cực nhất'),
                  style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 4),
              MostActiveFarmersList(farmers: summary.mostActiveFarmers),
              SizedBox(height: 24),
              Text(adminText(context, 'Cần xử lý'),
                  style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 4),
              PendingActionsList(actions: summary.pendingActions),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loading (pattern #6): dùng gói `shimmer` bọc khối màu nền đúng
/// hình dạng nội dung thật, KHÔNG dùng CircularProgressIndicator toàn trang.
class _DashboardSkeleton extends StatelessWidget {
  _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _block(context, 90)),
              SizedBox(width: 12),
              Expanded(child: _block(context, 90)),
            ],
          ),
          SizedBox(height: 24),
          _block(context, 220),
          SizedBox(height: 24),
          _block(context, 140),
        ],
      ),
    );
  }

  Widget _block(BuildContext context, double height) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40),
          SizedBox(height: 8),
          Text(adminText(context, 'Không tải được dữ liệu.')),
          SizedBox(height: 8),
          OutlinedButton(
              onPressed: onRetry, child: Text(adminText(context, 'Thử lại'))),
        ],
      ),
    );
  }
}
