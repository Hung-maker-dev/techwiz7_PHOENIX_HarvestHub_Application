import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_repository.dart';
import 'language_switcher.dart';
import 'theme_toggle.dart';

class RoleAccountScaffold extends StatefulWidget {
  const RoleAccountScaffold({
    required this.role,
    required this.child,
    super.key,
  });

  final String role;
  final Widget child;

  @override
  State<RoleAccountScaffold> createState() => _RoleAccountScaffoldState();
}

class _RoleAccountScaffoldState extends State<RoleAccountScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _RoleAccountDrawer(role: widget.role),
      body: _RoleMenuScope(
        scaffoldKey: _scaffoldKey,
        child: widget.child,
      ),
    );
  }
}

class _RoleMenuScope extends InheritedWidget {
  const _RoleMenuScope({
    required this.scaffoldKey,
    required super.child,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;

  static GlobalKey<ScaffoldState>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RoleMenuScope>()?.scaffoldKey;

  @override
  bool updateShouldNotify(_RoleMenuScope oldWidget) =>
      scaffoldKey != oldWidget.scaffoldKey;
}

class RoleMenuButton extends StatelessWidget {
  const RoleMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = _RoleMenuScope.maybeOf(context);
    return IconButton(
      tooltip: 'common.shared.openMenu'.tr(),
      icon: const Icon(Icons.menu),
      onPressed: () => scaffoldKey?.currentState?.openDrawer(),
    );
  }
}

class _RoleAccountDrawer extends ConsumerWidget {
  const _RoleAccountDrawer({required this.role});

  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final isFarmer = role == 'farmer';
    final entries = isFarmer
        ? <(IconData, String, String)>[
            (
              Icons.dashboard_outlined,
              'common.farmer.navigation.dashboard',
              '/farmer/dashboard'
            ),
            (
              Icons.inventory_2_outlined,
              'common.farmer.navigation.products',
              '/farmer/products'
            ),
            (
              Icons.receipt_long_outlined,
              'common.farmer.navigation.orders',
              '/farmer/orders'
            ),
            (
              Icons.access_time_outlined,
              'common.farmer.navigation.pickupSlots',
              '/farmer/pickup-slots'
            ),
            (
              Icons.bar_chart_outlined,
              'common.farmer.navigation.reports',
              '/farmer/reports'
            ),
            (
              Icons.star_outline,
              'common.farmer.navigation.community',
              '/farmer/reviews'
            ),
            (
              Icons.storefront_outlined,
              'common.farmer.navigation.profile',
              '/farmer/profile'
            ),
            (
              Icons.notifications_outlined,
              'common.farmer.navigation.notifications',
              '/farmer/notifications'
            ),
          ]
        : <(IconData, String, String)>[
            (Icons.storefront_outlined, 'account.home.shop', '/shop'),
            (Icons.receipt_long_outlined, 'account.home.orders', '/orders'),
            (Icons.favorite_border, 'account.home.wishlist', '/wishlist'),
            (Icons.person_outline, 'account.home.following', '/following'),
            (
              Icons.agriculture_outlined,
              'account.home.farmerDirectory',
              '/customer/farmers'
            ),
            (
              Icons.notifications_outlined,
              'account.home.notifications',
              '/notifications'
            ),
            (
              Icons.account_circle_outlined,
              'account.home.profile',
              '/account/profile'
            ),
          ];

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UserAccountsDrawerHeader(
              currentAccountPicture: CircleAvatar(
                child: Icon(isFarmer ? Icons.agriculture : Icons.person),
              ),
              accountName: Text(
                user?.displayName ?? user?.email ?? 'HarvestHub',
              ),
              accountEmail: Text(user?.email ?? ''),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final (icon, label, route) in entries)
                    ListTile(
                      leading: Icon(icon),
                      title: Text(label.tr()),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go(route);
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text('common.moreSheet.language'.tr()),
              trailing: const LanguageSwitcher(),
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: Text('common.moreSheet.theme'.tr()),
              trailing: const ThemeToggle(),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text('common.home.logout'.tr()),
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/auth');
                } catch (error, stackTrace) {
                  debugPrint(
                    'Could not sign out from role menu: $error\n$stackTrace',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('common.auth.errorGeneric'.tr()),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
