import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_role_provider.dart';
import '../../shared_widgets/language_switcher.dart';
import '../../shared_widgets/theme_toggle.dart';
import 'admin_localization.dart';
import 'widgets/admin_nav_item.dart';

class AdminNavEntry {
  const AdminNavEntry(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
}

const List<AdminNavEntry> kAdminNavEntries = [
  AdminNavEntry(Icons.dashboard_outlined, 'Bảng điều khiển', '/admin'),
  AdminNavEntry(Icons.people_outline, 'Tài khoản', '/admin/accounts'),
  AdminNavEntry(Icons.agriculture_outlined, 'Nông dân', '/admin/farmers'),
  AdminNavEntry(Icons.inventory_2_outlined, 'Sản phẩm', '/admin/products'),
  AdminNavEntry(Icons.category_outlined, 'Danh mục', '/admin/categories'),
  AdminNavEntry(Icons.storefront_outlined, 'Chợ', '/admin/markets'),
  AdminNavEntry(Icons.receipt_long_outlined, 'Đơn hàng', '/admin/orders'),
  AdminNavEntry(
      Icons.mail_outline, 'Phản hồi liên hệ', '/admin/contact-messages'),
  AdminNavEntry(Icons.bar_chart_outlined, 'Báo cáo', '/admin/reports'),
  AdminNavEntry(
      Icons.history_outlined, 'Nhật ký hoạt động', '/admin/audit-log'),
];

class AdminShell extends ConsumerWidget {
  const AdminShell({
    super.key,
    required this.currentRoute,
    required this.title,
    required this.child,
    this.actions,
  });

  final String currentRoute;
  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);
    return role.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const _AdminGuardDenied(),
      data: (value) => value == 'admin'
          ? _buildAdmin(context, ref, FirebaseAuth.instance.currentUser)
          : const _AdminGuardDenied(),
    );
  }

  Widget _buildAdmin(BuildContext context, WidgetRef ref, User? user) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (actions != null) ...actions!,
          const LanguageSwitcher(),
          const ThemeToggle(),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined, size: 32),
                    const SizedBox(height: 8),
                    Text(
                        user?.displayName ??
                            adminText(context, 'Admin kiểm tra'),
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(user?.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final entry in kAdminNavEntries)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: AdminNavItem(
                          icon: entry.icon,
                          label: adminText(context, entry.label),
                          selected: entry.route == currentRoute,
                          onTap: () {
                            Navigator.of(context).pop(); // đóng Drawer trước
                            if (entry.route != currentRoute) {
                              context.go(entry.route);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(adminText(context, 'Đăng xuất')),
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) context.go('/');
                  } catch (error, stackTrace) {
                    debugPrint('Admin sign-out failed: $error\n$stackTrace');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(adminText(context,
                              'Không thể đăng xuất. Vui lòng thử lại.')),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: child,
    );
  }
}

class _AdminGuardDenied extends StatelessWidget {
  const _AdminGuardDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 48),
            const SizedBox(height: 12),
            Text(adminText(
                context, 'Bạn không có quyền truy cập trang quản trị.')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/'),
              child: Text(adminText(context, 'Về trang chủ')),
            ),
          ],
        ),
      ),
    );
  }
}
