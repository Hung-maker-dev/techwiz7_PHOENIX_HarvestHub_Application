import 'package:go_router/go_router.dart';

import '../../models/admin/admin_contact_message.dart';
import '../../models/admin/admin_farmer.dart';
import 'accounts_page.dart';
import 'audit_log_page.dart';
import 'categories_page.dart';
import 'contact_messages_page.dart';
import 'customers_page.dart';
import 'dashboard_page.dart';
import 'farmers_page.dart';
import 'markets_page.dart';
import 'orders_page.dart';
import 'products_page.dart';
import 'reports_page.dart';

final List<GoRoute> adminRoutes = [
  GoRoute(
    path: '/admin',
    builder: (context, state) => const AdminDashboardPage(),
  ),
  GoRoute(
    path: '/admin/customers',
    builder: (context, state) => const AdminCustomersPage(),
  ),
  GoRoute(
    path: '/admin/accounts',
    builder: (context, state) => const AdminAccountsPage(),
  ),
  GoRoute(
    path: '/admin/farmers',
    builder: (context, state) {
      final statusParam = state.uri.queryParameters['status'];
      return AdminFarmersPage(
        initialStatus:
            statusParam == null ? null : farmerStatusFromString(statusParam),
      );
    },
  ),
  GoRoute(
    path: '/admin/products',
    builder: (context, state) => const AdminProductsPage(),
  ),
  GoRoute(
    path: '/admin/categories',
    builder: (context, state) => const AdminCategoriesPage(),
  ),
  GoRoute(
    path: '/admin/markets',
    builder: (context, state) => const AdminMarketsPage(),
  ),
  GoRoute(
    path: '/admin/orders',
    builder: (context, state) => const AdminOrdersPage(),
  ),
  GoRoute(
    path: '/admin/contact-messages',
    builder: (context, state) {
      final statusParam = state.uri.queryParameters['status'];
      return AdminContactMessagesPage(
        initialStatus:
            statusParam == null ? null : contactStatusFromString(statusParam),
      );
    },
  ),
  GoRoute(
    path: '/admin/reports',
    builder: (context, state) => const AdminReportsPage(),
  ),
  GoRoute(
    path: '/admin/audit-log',
    builder: (context, state) => const AdminAuditLogPage(),
  ),
];
