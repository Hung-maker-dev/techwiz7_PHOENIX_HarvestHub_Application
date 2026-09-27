import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

/// Role THẬT của user hiện tại, luôn được lấy từ backend (bảng `users`
/// trong MySQL) — KHÔNG BAO GIỜ lấy từ URL, query parameter, hay bất kỳ
/// giá trị nào do client tự khai.
///
/// Provider này tự động chạy lại mỗi khi trạng thái đăng nhập Firebase
/// thay đổi (đăng nhập / đăng xuất / khởi động app khi đã có session cũ),
/// vì nó `watch` vào [authStateProvider].
///
/// - Khi chưa đăng nhập (`user == null`) -> trả về 'customer' (mặc định
///   an toàn nhất, không có quyền gì đặc biệt).
/// - Khi đã đăng nhập -> gọi backend để lấy role thật, không tin bất cứ
///   giá trị nào có sẵn ở phía client.
final userRoleProvider = FutureProvider<String>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) {
    return 'customer';
  }

  final repo = ref.watch(authRepositoryProvider);
  final role = await repo.fetchCurrentRole();

  // Nếu backend không xác nhận được role (offline, lỗi mạng, v.v.),
  // KHÔNG được mặc định là 'admin' hay bất cứ role có quyền cao hơn.
  // Luôn fallback về role thấp nhất.
  return role ?? 'customer';
});
