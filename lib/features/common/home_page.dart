import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_role_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared_widgets/app_card.dart';
import '../../shared_widgets/language_switcher.dart';
import '../../shared_widgets/theme_toggle.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String roleLabel(BuildContext context, String role) {
    switch (role) {
      case 'farmer':
        return 'common.home.roleFarmer'.tr();
      case 'admin':
        return 'common.home.roleAdmin'.tr();
      default:
        return 'common.home.roleBuyer'.tr();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    final roleAsync = ref.watch(userRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HarvestHub'),
        actions: [
          const LanguageSwitcher(),
          const ThemeToggle(),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: roleAsync.when(
        // Trong lúc chờ xác nhận role thật từ server, hiện loading —
        // TUYỆT ĐỐI không đoán bừa hay mặc định hiển thị nội dung admin.
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.space3),
            child: Text('common.auth.errorGeneric'.tr()),
          ),
        ),
        data: (role) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpace.space3),
              const Icon(Icons.eco, size: 64, color: Colors.green),
              const SizedBox(height: AppSpace.space2),
              Text(
                'common.home.welcome'.tr(
                  args: [user?.displayName ?? user?.email ?? ''],
                ),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpace.space1),
              Text(
                'common.home.roleHome'.tr(args: [roleLabel(context, role)]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.space4),
              Text(
                'common.home.testTitle'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.space2),
              _TestRouteCard(
                icon: Icons.info_outline,
                label: 'common.moreSheet.about'.tr(),
                onTap: () => context.push('/about'),
              ),
              _TestRouteCard(
                icon: Icons.mail_outline,
                label: 'common.moreSheet.contact'.tr(),
                onTap: () => context.push('/contact'),
              ),
              _TestRouteCard(
                icon: Icons.help_outline,
                label: 'common.moreSheet.faq'.tr(),
                onTap: () => context.push('/faq'),
              ),
              _TestRouteCard(
                icon: Icons.location_on_outlined,
                label: 'common.home.nearbyMarkets'.tr(),
                onTap: () => context.push('/nearby-markets'),
              ),
              if (role == 'customer')
                _TestRouteCard(
                  icon: Icons.agriculture_outlined,
                  label: 'account.home.farmerDirectory'.tr(),
                  onTap: () => context.push('/customer/farmers'),
                ),
              if (role == 'customer')
                _TestRouteCard(
                  icon: Icons.notifications_outlined,
                  label: 'account.home.notifications'.tr(),
                  onTap: () => context.push('/notifications'),
                ),
              if (role == 'customer')
                _TestRouteCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'account.home.orders'.tr(),
                  onTap: () => context.push('/orders'),
                ),
              if (role == 'customer')
                _TestRouteCard(
                  icon: Icons.favorite_border,
                  label: 'account.home.wishlist'.tr(),
                  onTap: () => context.push('/wishlist'),
                ),
              if (role == 'customer')
                _TestRouteCard(
                  icon: Icons.person_outline,
                  label: 'account.home.following'.tr(),
                  onTap: () => context.push('/following'),
                ),
              if (role == 'customer')
                _TestRouteCard(
                  icon: Icons.account_circle_outlined,
                  label: 'account.home.profile'.tr(),
                  onTap: () => context.push('/account/profile'),
                ),
              if (role == 'customer')
                _TestRouteCard(
                  icon: Icons.storefront_outlined,
                  label: 'account.home.shop'.tr(),
                  onTap: () => context.push('/shop'),
                ),
              if (role == 'customer')
                _TestRouteCard(
                  icon: Icons.storefront_outlined,
                  label: 'common.home.applyFarmer'.tr(),
                  onTap: () => context.push('/farmer-application'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestRouteCard extends StatelessWidget {
  const _TestRouteCard(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.space2),
      child: AppCard(
        interactive: true,
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpace.space2),
            Expanded(child: Text(label)),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
