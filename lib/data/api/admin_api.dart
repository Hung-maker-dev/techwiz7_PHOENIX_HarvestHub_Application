import 'package:dio/dio.dart';

import '../../models/admin/admin_category.dart';
import '../../models/admin/admin_account.dart';
import '../../models/admin/admin_contact_message.dart';
import '../../models/admin/admin_customer.dart';
import '../../models/admin/admin_farmer.dart';
import '../../models/admin/admin_market.dart';
import '../../models/admin/admin_order.dart';
import '../../models/admin/admin_product.dart';
import '../../models/admin/admin_user_option.dart';
import '../../models/admin/audit_log_entry.dart';
import '../../models/admin/dashboard_summary.dart';
import '../../models/admin/system_report.dart';

class AdminApi {
  AdminApi(this._dio);

  final Dio _dio;

  Future<DashboardSummary> fetchDashboardSummary() async {
    final res = await _dio.get('/api/reports/system/summary');
    return DashboardSummary.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<AdminCustomer>> fetchCustomers({String? query}) async {
    final res = await _dio.get('/api/admin/customers', queryParameters: {
      if (query != null && query.isNotEmpty) 'q': query,
    });
    return (res.data as List)
        .map((e) => AdminCustomer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminCustomer> fetchCustomerDetail(String id) async {
    final res = await _dio.get('/api/admin/customers/$id');
    return AdminCustomer.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<AdminUserOption>> fetchAdminUsers() async {
    final res = await _dio.get('/api/admin/users');
    return (res.data as List)
        .map((e) => AdminUserOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminAccount>> fetchAccounts({
    String query = '',
    String type = 'all',
    String status = 'all',
  }) async {
    final response = await _dio.get(
      '/api/admin/accounts',
      queryParameters: {
        if (query.isNotEmpty) 'q': query,
        'type': type,
        'status': status,
      },
    );
    return (response.data as List)
        .map((item) => AdminAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminFarmer>> fetchFarmers({FarmerStatus? status}) async {
    final res = await _dio.get('/api/admin/farmers', queryParameters: {
      if (status != null) 'status': farmerStatusToString(status),
    });
    return (res.data as List)
        .map((e) => AdminFarmer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> approveFarmer(String id) async {
    final response = await _dio.patch('/api/admin/farmers/$id/approve');
    return response.data is Map &&
        response.data['email_notification_sent'] == true;
  }

  Future<void> rejectFarmer(String id) =>
      _dio.patch('/api/admin/farmers/$id/reject');

  Future<void> lockFarmer(String id, bool locked) =>
      _dio.patch('/api/admin/farmers/$id/lock', data: {'locked': locked});

  Future<List<AdminProduct>> fetchProducts({
    String? farmerId,
    String? categoryId,
    String? status,
  }) async {
    final res = await _dio.get('/api/admin/products', queryParameters: {
      if (farmerId != null) 'farmer': farmerId,
      if (categoryId != null) 'category': categoryId,
      if (status != null) 'status': status,
    });
    return (res.data as List)
        .map((e) => AdminProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// [reason] bắt buộc — AlertDialog ở 4.4 yêu cầu ô lý do trước khi gửi.
  Future<void> hideProduct(String id, String reason) =>
      _dio.patch('/api/admin/products/$id/hide', data: {'reason': reason});

  Future<List<AdminCategory>> fetchCategories() async {
    final res = await _dio.get('/api/admin/categories');
    return (res.data as List)
        .map((e) => AdminCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminCategory> createCategory(AdminCategory draft) async {
    final res = await _dio.post('/api/admin/categories', data: draft.toJson());
    return AdminCategory.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AdminCategory> updateCategory(String id, AdminCategory draft) async {
    final res =
        await _dio.patch('/api/admin/categories/$id', data: draft.toJson());
    return AdminCategory.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String id) =>
      _dio.delete('/api/admin/categories/$id');

  /// [orderedIds] là mảng id theo thứ tự mới, gửi sau khi `onReorder` của
  /// `ReorderableListView` đã cập nhật local state (đúng luồng mô tả ở 4.5).
  Future<void> reorderCategories(List<String> orderedIds) => _dio.patch(
        '/api/admin/categories/reorder',
        data: {'orderedIds': orderedIds},
      );

  Future<List<AdminMarket>> fetchMarkets() async {
    final res = await _dio.get('/api/admin/markets');
    return (res.data as List)
        .map((e) => AdminMarket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminMarket> createMarket(AdminMarket draft) async {
    final res = await _dio.post('/api/admin/markets', data: draft.toJson());
    return AdminMarket.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AdminMarket> updateMarket(String id, AdminMarket draft) async {
    final res =
        await _dio.patch('/api/admin/markets/$id', data: draft.toJson());
    return AdminMarket.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteMarket(String id) => _dio.delete('/api/admin/markets/$id');

  Future<List<AdminOrder>> fetchOrders({
    String? status,
    String? marketId,
    DateTime? from,
    DateTime? to,
  }) async {
    final res = await _dio.get('/api/admin/orders', queryParameters: {
      if (status != null) 'status': status,
      if (marketId != null) 'market': marketId,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    });
    return (res.data as List)
        .map((e) => AdminOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminContactMessage>> fetchContactMessages({
    ContactMessageStatus? status,
  }) async {
    final res = await _dio.get('/api/admin/contact-messages', queryParameters: {
      if (status != null) 'status': status.name,
    });
    return (res.data as List)
        .map((e) => AdminContactMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> resolveContactMessage(String id) =>
      _dio.patch('/api/admin/contact-messages/$id/resolve');

  Future<SystemReport> fetchSystemReport(ReportPeriod period) async {
    final res = await _dio.get('/api/reports/system', queryParameters: {
      'period': period.apiValue,
    });
    return SystemReport.fromJson(res.data as Map<String, dynamic>,
        period: period);
  }

  Future<List<AuditLogEntry>> fetchAuditLog({
    String? actorId,
    DateTime? from,
    DateTime? to,
  }) async {
    final res = await _dio.get('/api/admin/audit-log', queryParameters: {
      if (actorId != null) 'actor': actorId,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    });
    return (res.data as List)
        .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
