class MarketRevenue {
  final String marketId;
  final String marketName;
  final double revenue;
  final int orderCount;

  const MarketRevenue({
    required this.marketId,
    required this.marketName,
    required this.revenue,
    required this.orderCount,
  });

  factory MarketRevenue.fromJson(Map<String, dynamic> json) => MarketRevenue(
        marketId: (json['marketId'] ?? json['market_id']).toString(),
        marketName: (json['marketName'] ?? json['market_name'] ?? '') as String,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
        orderCount: (json['orderCount'] ?? json['order_count'] ?? 0) as int,
      );
}

class ActiveFarmerSummary {
  final String farmerId;
  final String farmName;
  final int orderCount;
  final double revenue;

  const ActiveFarmerSummary({
    required this.farmerId,
    required this.farmName,
    required this.orderCount,
    required this.revenue,
  });

  factory ActiveFarmerSummary.fromJson(Map<String, dynamic> json) =>
      ActiveFarmerSummary(
        farmerId: (json['farmerId'] ?? json['farmer_id']).toString(),
        farmName: (json['farmName'] ?? json['farm_name'] ?? '') as String,
        orderCount: (json['orderCount'] ?? json['order_count'] ?? 0) as int,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      );
}

class PendingAction {
  /// 'farmer_pending' | 'contact_message'
  final String type;
  final String id;
  final String title;
  final String subtitle;

  const PendingAction({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
  });

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
        type: json['type'] as String,
        id: json['id'].toString(),
        title: json['title'] as String,
        subtitle: (json['subtitle'] ?? '') as String,
      );

  /// Đích điều hướng khi tap vào mục này trong PendingActionsList
  /// (yêu cầu 4.1: "mỗi mục link thẳng tới màn hình tương ứng đã lọc sẵn").
  String get route {
    switch (type) {
      case 'farmer_pending':
        return '/admin/farmers?status=pending';
      case 'contact_message':
        return '/admin/contact-messages?status=new';
      default:
        return '/admin';
    }
  }
}

class DashboardSummary {
  final int totalOrders;
  final double totalRevenue;
  final List<MarketRevenue> revenueByMarket;
  final List<ActiveFarmerSummary> mostActiveFarmers;
  final List<PendingAction> pendingActions;

  const DashboardSummary({
    required this.totalOrders,
    required this.totalRevenue,
    required this.revenueByMarket,
    required this.mostActiveFarmers,
    required this.pendingActions,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
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
        pendingActions:
            ((json['pendingActions'] ?? json['pending_actions'] ?? []) as List)
                .map((e) => PendingAction.fromJson(e as Map<String, dynamic>))
                .toList(),
      );

  factory DashboardSummary.empty() => const DashboardSummary(
        totalOrders: 0,
        totalRevenue: 0,
        revenueByMarket: [],
        mostActiveFarmers: [],
        pendingActions: [],
      );
}
