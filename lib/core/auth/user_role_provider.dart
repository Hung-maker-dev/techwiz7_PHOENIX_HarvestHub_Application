import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

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
