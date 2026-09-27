// lib/models/admin/system_report.dart
//
// Dùng cho GET /api/reports/system?period= (4.9). Tái dùng MarketRevenue /
// ActiveFarmerSummary từ dashboard_summary.dart để không lặp model giữa
// Dashboard (4.1) và Reports (4.9) — hai màn dùng chung shape dữ liệu theo
// đúng mô tả "RevenueByMarketChart, MostActiveFarmersList" ở cả hai nơi.

import 'dashboard_summary.dart';

enum ReportPeriod { week, month, quarter, year }

class BestSellingProduct {
  const BestSellingProduct({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.revenue,
  });

  final String productId;
  final String productName;
  final int quantitySold;
  final double revenue;

  factory BestSellingProduct.fromJson(Map<String, dynamic> json) =>
      BestSellingProduct(
        productId: (json['productId'] ?? json['product_id']).toString(),
        productName:
            (json['productName'] ?? json['product_name'] ?? '') as String,
        quantitySold:
            (json['quantitySold'] ?? json['quantity_sold'] ?? 0) as int,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      );
}

class ActiveCustomerSummary {
  const ActiveCustomerSummary({
    required this.customerId,
    required this.customerName,
    required this.orderCount,
    required this.totalSpent,
  });

  final String customerId;
  final String customerName;
  final int orderCount;
  final double totalSpent;

  factory ActiveCustomerSummary.fromJson(Map<String, dynamic> json) =>
      ActiveCustomerSummary(
        customerId: (json['customerId'] ?? json['customer_id']).toString(),
        customerName:
            (json['customerName'] ?? json['customer_name'] ?? '') as String,
        orderCount: (json['orderCount'] ?? json['order_count'] ?? 0) as int,
        totalSpent: (json['totalSpent'] as num?)?.toDouble() ??
            (json['total_spent'] as num?)?.toDouble() ??
            0,
      );
}

extension ReportPeriodApi on ReportPeriod {
  String get apiValue => switch (this) {
        ReportPeriod.week => 'week',
        ReportPeriod.month => 'month',
        ReportPeriod.quarter => 'quarter',
        ReportPeriod.year => 'year',
      };
}

class SystemReport {
  final ReportPeriod period;
  final int totalOrders;
  final double totalRevenue;
  final List<MarketRevenue> revenueByMarket;
  final List<ActiveFarmerSummary> mostActiveFarmers;
  final List<BestSellingProduct> bestSellingProducts;
  final List<ActiveCustomerSummary> activeCustomers;

  const SystemReport({
    required this.period,
    required this.totalOrders,
    required this.totalRevenue,
    required this.revenueByMarket,
    required this.mostActiveFarmers,
    required this.bestSellingProducts,
    required this.activeCustomers,
  });

  factory SystemReport.fromJson(
    Map<String, dynamic> json, {
    required ReportPeriod period,
  }) =>
      SystemReport(
        period: period,
        totalOrders: (json['totalOrders'] ?? json['total_orders'] ?? 0) as int,
        totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ??
            (json['total_revenue'] as num?)?.toDouble() ??
            0,
        revenueByMarket: ((json['revenueByMarket'] ??
                json['revenue_by_market'] ??
                []) as List)
            .map((e) => MarketRevenue.fromJson(e as Map<String, dynamic>))
            .toList(),
        mostActiveFarmers: ((json['mostActiveFarmers'] ??
                json['most_active_farmers'] ??
                []) as List)
            .map((e) => ActiveFarmerSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        bestSellingProducts: ((json['bestSellingProducts'] ??
                json['best_selling_products'] ??
                []) as List)
            .map((e) => BestSellingProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        activeCustomers: ((json['activeCustomers'] ??
                json['active_customers'] ??
                []) as List)
            .map((e) =>
                ActiveCustomerSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
