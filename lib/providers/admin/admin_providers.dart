import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/admin_api.dart';
import '../../core/network/dio_client.dart' show dioProvider;
import '../../models/admin/admin_category.dart';
import '../../models/admin/admin_account.dart';
import '../../models/admin/admin_contact_message.dart';
import '../../models/admin/admin_customer.dart';
import '../../models/admin/admin_farmer.dart';
import '../../models/admin/admin_market.dart';
import '../../models/admin/admin_order.dart';
import '../../models/admin/admin_product.dart';
import '../../models/admin/audit_log_entry.dart';
import '../../models/admin/dashboard_summary.dart';
import '../../models/admin/system_report.dart';

final adminApiProvider = Provider<AdminApi>((ref) {
  return AdminApi(ref.watch(dioProvider));
});

final dashboardSummaryProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) {
  return ref.watch(adminApiProvider).fetchDashboardSummary();
});

final customerSearchQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');

final customersProvider =
    FutureProvider.autoDispose<List<AdminCustomer>>((ref) {
  final query = ref.watch(customerSearchQueryProvider);
  return ref.watch(adminApiProvider).fetchCustomers(query: query);
});

final customerDetailProvider =
    FutureProvider.autoDispose.family<AdminCustomer, String>((ref, id) {
  return ref.watch(adminApiProvider).fetchCustomerDetail(id);
});

final adminUsersProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(adminApiProvider).fetchAdminUsers();
});

final accountSearchQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');
final accountTypeFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'all');
final accountStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'all');

final adminAccountsProvider =
    FutureProvider.autoDispose<List<AdminAccount>>((ref) {
  return ref.watch(adminApiProvider).fetchAccounts(
        query: ref.watch(accountSearchQueryProvider),
        type: ref.watch(accountTypeFilterProvider),
        status: ref.watch(accountStatusFilterProvider),
      );
});

final farmerStatusFilterProvider =
    StateProvider.autoDispose<FarmerStatus?>((ref) => FarmerStatus.pending);

final farmersProvider = FutureProvider.autoDispose<List<AdminFarmer>>((ref) {
  final status = ref.watch(farmerStatusFilterProvider);
  return ref.watch(adminApiProvider).fetchFarmers(status: status);
});

final allFarmersProvider = FutureProvider.autoDispose<List<AdminFarmer>>((ref) {
  return ref.watch(adminApiProvider).fetchFarmers();
});

class FarmerActionsNotifier {
  FarmerActionsNotifier(this._ref);
  final Ref _ref;

  Future<bool> approve(String id) async {
    final emailSent = await _ref.read(adminApiProvider).approveFarmer(id);
    _ref.invalidate(farmersProvider);
    _ref.invalidate(adminAccountsProvider);
    _ref.invalidate(dashboardSummaryProvider);
    return emailSent;
  }

  Future<void> reject(String id) async {
    await _ref.read(adminApiProvider).rejectFarmer(id);
    _ref.invalidate(farmersProvider);
    _ref.invalidate(adminAccountsProvider);
    _ref.invalidate(dashboardSummaryProvider);
  }

  Future<void> toggleLock(String id, bool locked) async {
    await _ref.read(adminApiProvider).lockFarmer(id, locked);
    _ref.invalidate(farmersProvider);
  }
}

final farmerActionsProvider =
    Provider.autoDispose<FarmerActionsNotifier>((ref) {
  return FarmerActionsNotifier(ref);
});

class ProductFilter {
  final String? farmerId;
  final String? categoryId;
  final String? status;

  const ProductFilter({this.farmerId, this.categoryId, this.status});

  ProductFilter copyWith({
    String? farmerId,
    String? categoryId,
    String? status,
  }) =>
      ProductFilter(
        farmerId: farmerId ?? this.farmerId,
        categoryId: categoryId ?? this.categoryId,
        status: status ?? this.status,
      );
}

final productFilterProvider =
    StateProvider.autoDispose<ProductFilter>((ref) => const ProductFilter());

final adminProductsProvider =
    FutureProvider.autoDispose<List<AdminProduct>>((ref) {
  final f = ref.watch(productFilterProvider);
  return ref.watch(adminApiProvider).fetchProducts(
      farmerId: f.farmerId, categoryId: f.categoryId, status: f.status);
});

final hideProductProvider =
    Provider.autoDispose<Future<void> Function(String id, String reason)>(
        (ref) {
  return (id, reason) async {
    await ref.read(adminApiProvider).hideProduct(id, reason);
    ref.invalidate(adminProductsProvider);
  };
});

final categoriesProvider =
    FutureProvider.autoDispose<List<AdminCategory>>((ref) {
  return ref.watch(adminApiProvider).fetchCategories();
});

class CategoryActionsNotifier {
  CategoryActionsNotifier(this._ref);
  final Ref _ref;

  Future<void> create(AdminCategory draft) async {
    await _ref.read(adminApiProvider).createCategory(draft);
    _ref.invalidate(categoriesProvider);
  }

  Future<void> update(String id, AdminCategory draft) async {
    await _ref.read(adminApiProvider).updateCategory(id, draft);
    _ref.invalidate(categoriesProvider);
  }

  Future<void> remove(String id) async {
    await _ref.read(adminApiProvider).deleteCategory(id);
    _ref.invalidate(categoriesProvider);
  }

  Future<void> reorder(List<String> orderedIds) async {
    await _ref.read(adminApiProvider).reorderCategories(orderedIds);
    _ref.invalidate(categoriesProvider);
  }
}

final categoryActionsProvider =
    Provider.autoDispose<CategoryActionsNotifier>((ref) {
  return CategoryActionsNotifier(ref);
});

final marketsProvider = FutureProvider.autoDispose<List<AdminMarket>>((ref) {
  return ref.watch(adminApiProvider).fetchMarkets();
});

class MarketActionsNotifier {
  MarketActionsNotifier(this._ref);
  final Ref _ref;

  Future<void> create(AdminMarket draft) async {
    await _ref.read(adminApiProvider).createMarket(draft);
    _ref.invalidate(marketsProvider);
  }

  Future<void> update(String id, AdminMarket draft) async {
    await _ref.read(adminApiProvider).updateMarket(id, draft);
    _ref.invalidate(marketsProvider);
  }

  Future<void> remove(String id) async {
    await _ref.read(adminApiProvider).deleteMarket(id);
    _ref.invalidate(marketsProvider);
  }
}

final marketActionsProvider =
    Provider.autoDispose<MarketActionsNotifier>((ref) {
  return MarketActionsNotifier(ref);
});

class OrderFilter {
  final String? status;
  final String? marketId;
  final DateTime? from;
  final DateTime? to;

  const OrderFilter({this.status, this.marketId, this.from, this.to});

  OrderFilter copyWith({
    String? status,
    String? marketId,
    DateTime? from,
    DateTime? to,
  }) =>
      OrderFilter(
        status: status ?? this.status,
        marketId: marketId ?? this.marketId,
        from: from ?? this.from,
        to: to ?? this.to,
      );
}

final orderFilterProvider =
    StateProvider.autoDispose<OrderFilter>((ref) => const OrderFilter());

final adminOrdersProvider = FutureProvider.autoDispose<List<AdminOrder>>((ref) {
  final f = ref.watch(orderFilterProvider);
  return ref.watch(adminApiProvider).fetchOrders(
        status: f.status,
        marketId: f.marketId,
        from: f.from,
        to: f.to,
      );
});

final contactStatusFilterProvider =
    StateProvider.autoDispose<ContactMessageStatus>(
        (ref) => ContactMessageStatus.pending);

final contactMessagesProvider =
    FutureProvider.autoDispose<List<AdminContactMessage>>((ref) {
  final status = ref.watch(contactStatusFilterProvider);
  return ref.watch(adminApiProvider).fetchContactMessages(status: status);
});

final resolveContactMessageProvider =
    Provider.autoDispose<Future<void> Function(String id)>((ref) {
  return (id) async {
    await ref.read(adminApiProvider).resolveContactMessage(id);
    ref.invalidate(contactMessagesProvider);
    ref.invalidate(dashboardSummaryProvider);
  };
});

final reportPeriodProvider =
    StateProvider.autoDispose<ReportPeriod>((ref) => ReportPeriod.month);

final systemReportProvider = FutureProvider.autoDispose<SystemReport>((ref) {
  final period = ref.watch(reportPeriodProvider);
  return ref.watch(adminApiProvider).fetchSystemReport(period);
});

class AuditLogFilter {
  final String? actorId;
  final DateTime? from;
  final DateTime? to;

  const AuditLogFilter({this.actorId, this.from, this.to});

  AuditLogFilter copyWith({String? actorId, DateTime? from, DateTime? to}) =>
      AuditLogFilter(
        actorId: actorId ?? this.actorId,
        from: from ?? this.from,
        to: to ?? this.to,
      );
}

final auditLogFilterProvider =
    StateProvider.autoDispose<AuditLogFilter>((ref) => const AuditLogFilter());

final auditLogProvider = FutureProvider.autoDispose<List<AuditLogEntry>>((ref) {
  final f = ref.watch(auditLogFilterProvider);
  return ref.watch(adminApiProvider).fetchAuditLog(
        actorId: f.actorId,
        from: f.from,
        to: f.to,
      );
});
