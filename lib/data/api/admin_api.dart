// lib/data/api/admin_api.dart
//
// Tương đương "1 file / module backend" theo quy ước ở PROJECT_STRUCTURE.md
// (data/api/). Gộp mọi endpoint /api/admin/* + /api/reports/* dùng bởi
// module admin vào MỘT file (thay vì tách nhỏ theo từng màn 4.1-4.10) vì
// chúng đều thuộc modules/admin + modules/reports phía server — mọi widget
// gọi API phải đi qua đây, KHÔNG gọi `dio` thẳng trong page/widget.
//
// Giả định (cần Người 1 xác nhận khi merge):
//   - `dioProvider` (Riverpod `Provider<Dio>`) được định nghĩa ở
//     core/network/dio_client.dart, đã gắn interceptor Firebase ID token.
//   - Base URL đọc từ ENV (API_BASE_URL) đã cấu hình sẵn trong Dio instance,
//     nên các hàm dưới chỉ truyền path tương đối bắt đầu bằng /api/...

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

  // ---------------------------------------------------------------
  // 4.1 Dashboard
  // ---------------------------------------------------------------
  Future<DashboardSummary> fetchDashboardSummary() async {
    final res = await _dio.get('/api/reports/system/summary');
    return DashboardSummary.fromJson(res.data as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------
  // 4.2 Khách hàng
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // 4.3 Nông dân
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // 4.4 Sản phẩm (kiểm duyệt)
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // 4.5 Danh mục
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // 4.6 Chợ nông sản
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // 4.7 Đơn hàng (chỉ xem)
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // 4.8 Phản hồi liên hệ
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // 4.9 Báo cáo toàn hệ thống
  // ---------------------------------------------------------------
  Future<SystemReport> fetchSystemReport(ReportPeriod period) async {
    final res = await _dio.get('/api/reports/system', queryParameters: {
      'period': period.apiValue,
    });
    return SystemReport.fromJson(res.data as Map<String, dynamic>,
        period: period);
  }

  // ---------------------------------------------------------------
  // 4.10 Nhật ký hoạt động (chỉ đọc)
  // ---------------------------------------------------------------
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
