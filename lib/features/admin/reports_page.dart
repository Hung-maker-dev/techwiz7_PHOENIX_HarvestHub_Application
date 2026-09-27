// lib/features/admin/reports_page.dart
// Route: /admin/reports (NGUOI_5_MOBILE.md, 4.9)
//
// Nút "Xuất PDF/Excel" dùng gói `printing` + `pdf` — cùng cách làm đã dùng
// ở 3.6 (báo cáo nông dân, Người 4), theo đúng chỉ dẫn "như ở 3.6" trong
// NGUOI_5_MOBILE.md. `Printing.sharePdf` tự mở share sheet của hệ điều
// hành nên không cần thêm `share_plus` làm phương án dự phòng.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/admin/system_report.dart';
import '../../providers/admin/admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/most_active_farmers_list.dart';
import 'widgets/period_tabs.dart';
import 'widgets/revenue_by_market_chart.dart';
import 'widgets/stat_card.dart';
import 'admin_localization.dart';

String _reportPeriodLabel(BuildContext context, ReportPeriod period) {
  final label = switch (period) {
    ReportPeriod.week => 'Tuần',
    ReportPeriod.month => 'Tháng',
    ReportPeriod.quarter => 'Quý',
    ReportPeriod.year => 'Năm',
  };
  return adminText(context, label);
}

class AdminReportsPage extends ConsumerWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(systemReportProvider);
    final period = ref.watch(reportPeriodProvider);

    return AdminShell(
      currentRoute: '/admin/reports',
      title:
          adminText(context, 'Báo cáo hệ thống'), // i18n: admin.reports.title
      actions: [
        IconButton(
          icon: Icon(Icons.ios_share),
          tooltip: adminText(context, 'Xuất PDF'),
          onPressed: reportAsync.hasValue
              ? () => _exportPdf(context, reportAsync.requireValue)
              : null,
        ),
      ],
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          PeriodTabs(
            selected: period,
            onChanged: (p) => ref.read(reportPeriodProvider.notifier).state = p,
          ),
          SizedBox(height: 20),
          reportAsync.when(
            loading: () => Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(systemReportProvider),
                child: Text(
                    adminText(context, 'Không tải được báo cáo — thử lại')),
              ),
            ),
            data: (report) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    // count-up (pattern #8) — key theo period để tween lại
                    // từ 0 mỗi khi đổi kỳ báo cáo.
                    StatCard(
                      key: ValueKey('orders-${report.period}'),
                      label: adminText(context, 'Tổng đơn hàng'),
                      value: report.totalOrders.toDouble(),
                      icon: Icons.receipt_long_outlined,
                    ),
                    StatCard(
                      key: ValueKey('revenue-${report.period}'),
                      label: adminText(context, 'Tổng doanh thu'),
                      value: report.totalRevenue,
                      icon: Icons.payments_outlined,
                      valueFormatter: (v) => '${v.toStringAsFixed(0)}đ',
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text(adminText(context, 'Doanh thu theo chợ'),
                    style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 8),
                RevenueByMarketChart(data: report.revenueByMarket),
                SizedBox(height: 24),
                Text(adminText(context, 'Nông dân tích cực nhất'),
                    style: Theme.of(context).textTheme.titleMedium),
                MostActiveFarmersList(farmers: report.mostActiveFarmers),
                SizedBox(height: 24),
                Text(adminText(context, 'Sản phẩm bán nhiều nhất'),
                    style: Theme.of(context).textTheme.titleMedium),
                for (final product in report.bestSellingProducts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(product.productName),
                    subtitle: Text(adminText(
                        context, 'Đã bán ${product.quantitySold} sản phẩm')),
                    trailing: Text(adminText(
                        context, '${product.revenue.toStringAsFixed(0)}đ')),
                  ),
                SizedBox(height: 24),
                Text(adminText(context, 'Khách hàng tích cực'),
                    style: Theme.of(context).textTheme.titleMedium),
                for (final customer in report.activeCustomers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(customer.customerName),
                    subtitle:
                        Text(adminText(context, '${customer.orderCount} đơn')),
                    trailing: Text(adminText(
                        context, '${customer.totalSpent.toStringAsFixed(0)}đ')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context, SystemReport report) async {
    final reportTitle = adminText(context, 'Báo cáo hệ thống HarvestHub');
    final periodText = adminText(context, 'Kỳ báo cáo: {}')
        .replaceFirst('{}', _reportPeriodLabel(context, report.period));
    final orderTotalText = adminText(context, 'Tổng đơn hàng: {}')
        .replaceFirst('{}', '${report.totalOrders}');
    final revenueTotalText = adminText(context, 'Tổng doanh thu: {}đ')
        .replaceFirst('{}', report.totalRevenue.toStringAsFixed(0));
    final revenueByMarketTitle = adminText(context, 'Doanh thu theo chợ');
    final mostActiveFarmersTitle = adminText(context, 'Nông dân tích cực nhất');
    final bestSellingProductsTitle =
        adminText(context, 'Sản phẩm bán nhiều nhất');
    final activeCustomersTitle = adminText(context, 'Khách hàng tích cực');
    final marketHeader = adminText(context, 'Chợ');
    final farmerHeader = adminText(context, 'Nông dân');
    final customerHeader = adminText(context, 'Khách hàng');
    final productHeader = adminText(context, 'Sản phẩm');
    final orderCountHeader = adminText(context, 'Số đơn');
    final quantityHeader = adminText(context, 'Số lượng');
    final revenueHeader = adminText(context, 'Doanh thu');
    final spendingHeader = adminText(context, 'Chi tiêu');
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(reportTitle,
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text(periodText),
            pw.Text(orderTotalText),
            pw.Text(revenueTotalText),
            pw.SizedBox(height: 16),
            pw.Text(revenueByMarketTitle,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Table.fromTextArray(
              headers: [marketHeader, orderCountHeader, revenueHeader],
              data: [
                for (final m in report.revenueByMarket)
                  [
                    m.marketName,
                    '${m.orderCount}',
                    m.revenue.toStringAsFixed(0)
                  ],
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(mostActiveFarmersTitle,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Table.fromTextArray(
              headers: [farmerHeader, orderCountHeader, revenueHeader],
              data: [
                for (final f in report.mostActiveFarmers)
                  [f.farmName, '${f.orderCount}', f.revenue.toStringAsFixed(0)],
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(bestSellingProductsTitle,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Table.fromTextArray(
              headers: [productHeader, quantityHeader, revenueHeader],
              data: [
                for (final product in report.bestSellingProducts)
                  [
                    product.productName,
                    '${product.quantitySold}',
                    product.revenue.toStringAsFixed(0)
                  ],
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(activeCustomersTitle,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Table.fromTextArray(
              headers: [customerHeader, orderCountHeader, spendingHeader],
              data: [
                for (final customer in report.activeCustomers)
                  [
                    customer.customerName,
                    '${customer.orderCount}',
                    customer.totalSpent.toStringAsFixed(0)
                  ],
              ],
            ),
          ],
        ),
      ),
    );

    try {
      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'bao-cao-he-thong-${report.period.apiValue}.pdf',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(adminText(context, 'Đã tạo báo cáo PDF.'))),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('PDF export failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  adminText(context, 'Không thể xuất PDF trên thiết bị này.'))),
        );
      }
    }
  }
}
