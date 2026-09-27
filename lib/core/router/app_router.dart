import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_repository.dart';
import '../theme/app_motion.dart';
import '../../features/common/login_page.dart';
import '../../features/common/account_setup_page.dart';
import '../../features/common/forgot_password_page.dart';
import '../../features/common/about_page.dart';
import '../../features/common/contact_page.dart';
import '../../features/common/faq_page.dart';
import '../../features/common/home_page.dart';
import '../../features/common/nearby_markets_page.dart';
import '../../features/common/farmer_application_page.dart';
import '../../features/common/farmer_directory_page.dart';
import '../../features/common/customer_notifications_page.dart';
import '../../features/customer/customer_pages.dart';
import '../../features/farmer/dashboard_page.dart';
import '../../features/farmer/farm_profile_page.dart';
import '../../features/farmer/farmer_home_page.dart';
import '../../features/farmer/farmer_product_form_page.dart';
import '../../features/farmer/farmer_shell.dart';
import '../../features/farmer/farmer_tools_pages.dart';
import '../../features/farmer/orders_page.dart';
import '../../features/admin/admin_routes.dart';

/// Route transition dùng chung — fade + dịch dọc 8px, cấu hình MỘT LẦN ở
/// đây (pattern #7), không lặp lại ở từng page.
CustomTransitionPage<T> _buildPage<T>(Widget child) {
  return CustomTransitionPage<T>(
    child: child,
    transitionDuration: AppDurations.standard,
    reverseTransitionDuration: AppDurations.standard,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: AppCurves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
                  .animate(curved),
          child: child,
        ),
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/auth',
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) => _buildPage(const LoginPage()),
      ),
      GoRoute(
        path: '/account-setup',
        pageBuilder: (context, state) => _buildPage(const AccountSetupPage()),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => _buildPage(const HomePage()),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        pageBuilder: (context, state) => _buildPage(const ForgotPasswordPage()),
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (context, state) => _buildPage(const AboutPage()),
      ),
      GoRoute(
        path: '/contact',
        pageBuilder: (context, state) => _buildPage(const ContactPage()),
      ),
      GoRoute(
        path: '/faq',
        pageBuilder: (context, state) => _buildPage(const FaqPage()),
      ),
      GoRoute(
        path: '/nearby-markets',
        pageBuilder: (context, state) => _buildPage(const NearbyMarketsPage()),
      ),
      GoRoute(
        path: '/farmer-application',
        pageBuilder: (context, state) =>
            _buildPage(const FarmerApplicationPage()),
      ),
      GoRoute(
        path: '/customer/farmers',
        builder: (context, state) => const FarmerDirectoryPage(),
      ),
      GoRoute(
        path: '/customer/notifications',
        builder: (context, state) => const CustomerNotificationsPage(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrderHistoryPage(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) => OrderDetailPage(
          orderId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => const WishlistPage(),
      ),
      GoRoute(
        path: '/following',
        builder: (context, state) => const FollowingPage(),
      ),
      GoRoute(
        path: '/farmers/:id',
        builder: (context, state) => FarmerProfilePage(
          farmerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/account/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const CustomerNotificationsPage(),
      ),
      GoRoute(
        path: '/shop',
        builder: (context, state) => const ProductShopPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => FarmerShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/farmer',
            redirect: (context, state) => '/farmer/dashboard',
          ),
          GoRoute(
            path: '/farmer/dashboard',
            builder: (context, state) => const FarmerDashboardPage(),
          ),
          GoRoute(
            path: '/farmer/products',
            builder: (context, state) => const FarmerHomePage(),
          ),
          GoRoute(
            path: '/farmer/products/new',
            builder: (context, state) => const FarmerProductFormPage(),
          ),
          GoRoute(
            path: '/farmer/products/:id/edit',
            builder: (context, state) => FarmerProductFormPage(
              productId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/farmer/orders',
            builder: (context, state) => const FarmerOrdersPage(),
          ),
          GoRoute(
            path: '/farmer/profile',
            builder: (context, state) => const FarmProfilePage(),
          ),
          GoRoute(
            path: '/farmer/pickup-slots',
            builder: (context, state) => const FarmerPickupSlotsPage(),
          ),
          GoRoute(
            path: '/farmer/reports',
            builder: (context, state) => const FarmerReportsPage(),
          ),
          GoRoute(
            path: '/farmer/reviews',
            builder: (context, state) => const FarmerReviewsPage(),
          ),
          GoRoute(
            path: '/farmer/notifications',
            builder: (context, state) => const FarmerNotificationsPage(),
          ),
        ],
      ),
      ...adminRoutes,
    ],
    redirect: (context, state) async {
      final location = state.matchedLocation;
      final authRepository = ref.read(authRepositoryProvider);
      final user = authRepository.currentUser;
      if (location == '/') return '/auth';
      if (location == '/auth' && user != null) {
        try {
          final role = await authRepository.fetchCurrentRole();
          if (role == null) return '/account-setup';
          return switch (role) {
            'admin' => '/admin',
            'farmer' => '/farmer/dashboard',
            _ => '/home',
          };
        } catch (error, stackTrace) {
          debugPrint(
              'Could not resolve signed-in account role: $error\n$stackTrace');
          return null;
        }
      }
      if (location == '/account-setup') {
        if (user == null) return '/auth';
        try {
          final role = await authRepository.fetchCurrentRole();
          if (role != null) {
            return switch (role) {
              'admin' => '/admin',
              'farmer' => '/farmer/dashboard',
              _ => '/home',
            };
          }
        } catch (error, stackTrace) {
          debugPrint(
              'Could not check account setup status: $error\n$stackTrace');
          return null;
        }
      }
      if (location == '/home' && user == null) return '/auth';
      if (location == '/farmer-application' && user == null) {
        return '/auth';
      }
      if (location.startsWith('/admin')) {
        if (user == null) return '/auth';
        String? role;
        try {
          role = await authRepository.fetchCurrentRole();
        } catch (error, stackTrace) {
          debugPrint(
              'Could not verify admin route access: $error\n$stackTrace');
          return '/auth';
        }
        if (role == null) return '/account-setup';
        if (role != 'admin') return '/home';
      } else if (location == '/farmer' || location.startsWith('/farmer/')) {
        if (user == null) return '/auth';
        try {
          final role = await authRepository.fetchCurrentRole();
          if (role == null) return '/account-setup';
          if (role == 'admin') return '/admin';
          if (role != 'farmer') return '/home';
        } catch (error, stackTrace) {
          debugPrint(
              'Could not verify farmer route access: $error\n$stackTrace');
          return '/auth';
        }
      } else if (location.startsWith('/customer/') ||
          location == '/orders' ||
          location.startsWith('/orders/') ||
          location == '/wishlist' ||
          location == '/following' ||
          location.startsWith('/farmers/') ||
          location == '/account/profile' ||
          location == '/notifications' ||
          location == '/shop') {
        if (user == null) return '/auth';
        try {
          final role = await authRepository.fetchCurrentRole();
          if (role == null) return '/account-setup';
          if (role == 'admin') return '/admin';
          if (role == 'farmer') return '/farmer/dashboard';
          if (role != 'customer') return '/home';
        } catch (error, stackTrace) {
          debugPrint(
              'Could not verify customer route access: $error\n$stackTrace');
          return '/auth';
        }
      } else if (location == '/home' && user != null) {
        try {
          final role = await authRepository.fetchCurrentRole();
          if (role == null) return '/account-setup';
          if (role == 'admin') return '/admin';
          if (role == 'farmer') return '/farmer/dashboard';
        } catch (error, stackTrace) {
          debugPrint('Could not verify home route access: $error\n$stackTrace');
          return '/auth';
        }
      } else if (location == '/farmer-application' && user != null) {
        try {
          final role = await authRepository.fetchCurrentRole();
          if (role == null) return '/account-setup';
          if (role == 'admin') return '/admin';
          if (role == 'farmer') return '/home';
        } catch (error, stackTrace) {
          debugPrint(
              'Could not verify farmer application route access: $error\n$stackTrace');
          return '/auth';
        }
      }
      return null;
    },
  );

  ref.listen(authStateProvider, (previous, next) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});
