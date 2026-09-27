import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FarmerShell extends StatelessWidget {
  final Widget child;
  final String location;

  const FarmerShell({
    super.key,
    required this.child,
    required this.location,
  });

  int get selectedIndex {
    if (location.startsWith('/farmer/orders')) return 2;
    if (location.startsWith('/farmer/products')) return 1;
    if (!location.startsWith('/farmer/dashboard')) return 3;
    if (location.startsWith('/farmer/dashboard')) return 0;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/farmer/dashboard');
        break;
      case 1:
        context.go('/farmer/products');
        break;
      case 2:
        context.go('/farmer/orders');
        break;
      case 3:
        _showMoreMenu(context);
        break;
    }
  }

  Future<void> _showMoreMenu(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thêm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _SheetItem(
                icon: Icons.access_time_filled_outlined,
                title: 'Khung giờ nhận hàng',
                onTap: () => context.go('/farmer/pickup-slots'),
              ),
              _SheetItem(
                icon: Icons.bar_chart_rounded,
                title: 'Báo cáo',
                onTap: () => context.go('/farmer/reports'),
              ),
              _SheetItem(
                icon: Icons.star_outline_rounded,
                title: 'Người theo dõi & đánh giá',
                onTap: () => context.go('/farmer/reviews'),
              ),
              _SheetItem(
                icon: Icons.storefront_outlined,
                title: 'Hồ sơ trang trại',
                onTap: () => context.go('/farmer/profile'),
              ),
              _SheetItem(
                icon: Icons.notifications_none_rounded,
                title: 'Thông báo',
                onTap: () => context.go('/farmer/notifications'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted) return;
    if (result != null) {
      context.go(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                  child: _NavItem(
                label: 'Dashboard',
                icon: Icons.dashboard_outlined,
                active: selectedIndex == 0,
                onTap: () => _onItemTapped(context, 0),
              )),
              Expanded(
                  child: _NavItem(
                label: 'Sản phẩm',
                icon: Icons.inventory_2_outlined,
                active: selectedIndex == 1,
                onTap: () => _onItemTapped(context, 1),
              )),
              Expanded(
                  child: _NavItem(
                label: 'Đơn hàng',
                icon: Icons.receipt_long_outlined,
                active: selectedIndex == 2,
                onTap: () => _onItemTapped(context, 2),
              )),
              Expanded(
                  child: _NavItem(
                label: 'Thêm',
                icon: Icons.add_circle_outline,
                active: selectedIndex == 3,
                onTap: () => _onItemTapped(context, 3),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: active ? Alignment.topCenter : Alignment.center,
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SheetItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}
