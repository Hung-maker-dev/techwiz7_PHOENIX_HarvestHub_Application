// lib/features/admin/widgets/revenue_by_market_chart.dart
//
// Dùng ở Dashboard (4.1) và Reports (4.9), như đã nêu trong NGUOI_5_MOBILE.md
// ("RevenueByMarketChart (fl_chart)"). fl_chart tự animate khi đổi dữ liệu
// (swapAnimationDuration) nên không cần bọc thêm AnimatedSwitcher — tránh
// animate 2 lớp chồng nhau.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/admin/dashboard_summary.dart';
import '../admin_localization.dart';

class RevenueByMarketChart extends StatelessWidget {
  RevenueByMarketChart({super.key, required this.data});

  final List<MarketRevenue> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
            child: Text(adminText(context, 'Chưa có dữ liệu doanh thu'))),
      );
    }
    final maxRevenue =
        data.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);
    final chartMax = maxRevenue == 0 ? 1.0 : maxRevenue * 1.2;

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          maxY: chartMax,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => theme.colorScheme.inverseSurface,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final market = _marketLabel(data[group.x.toInt()]);
                return BarTooltipItem(
                  '$market\n${_formatCurrency(rod.toY)}',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                interval: chartMax / 4,
                getTitlesWidget: (value, meta) => Text(
                  _formatAmount(value),
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return SizedBox.shrink();
                  final label = _marketLabel(data[i]);
                  return Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: data[i].revenue,
                  color: theme.colorScheme.primary,
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  String _formatCurrency(double value) => '${value.toStringAsFixed(0)}đ';

  String _marketLabel(MarketRevenue market) {
    final name = market.marketName.trim();
    if (name.isEmpty) return 'Chưa xác định';
    return name.replaceFirst(RegExp(r'^Chợ nông sản\s*'), '').trim();
  }
}
