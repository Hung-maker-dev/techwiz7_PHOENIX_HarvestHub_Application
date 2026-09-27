import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';

/// AppBar dùng ở luồng khách hàng. `cartIconKey` là điểm neo cho pattern #1
/// (bay ảnh sản phẩm vào giỏ) — Người 2 truyền GlobalKey của icon giỏ hàng
/// khi gắn overlay animation ở Shop/ProductDetail/Cart.
class AppBarMain extends StatelessWidget implements PreferredSizeWidget {
  const AppBarMain({
    super.key,
    this.showSearch = true,
    this.cartCount = 0,
    this.cartIconKey,
    this.onSearchTap,
    this.onCartTap,
    this.onAccountTap,
  });

  final bool showSearch;
  final int cartCount;
  final GlobalKey? cartIconKey;
  final VoidCallback? onSearchTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onAccountTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          const _Logo(),
          if (showSearch) ...[
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onSearchTap,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                      SizedBox(width: 6),
                      Text('Tìm kiếm...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              key: cartIconKey,
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: onCartTap,
            ),
            if (cartCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: _CartBadge(count: cartCount),
              ),
          ],
        ),
        IconButton(icon: const Icon(Icons.person_outline), onPressed: onAccountTap),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return const Text(
      'HarvestHub',
      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary),
    );
  }
}

/// Badge số lượng — scale(1→1.15→1) khi số lượng thay đổi (pattern #1).
class _CartBadge extends StatefulWidget {
  const _CartBadge({required this.count});
  final int count;

  @override
  State<_CartBadge> createState() => _CartBadgeState();
}

class _CartBadgeState extends State<_CartBadge> {
  int? _lastCount;

  @override
  Widget build(BuildContext context) {
    final changed = _lastCount != null && _lastCount != widget.count;
    _lastCount = widget.count;

    Widget badge = Container(
      padding: const EdgeInsets.all(3),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
      child: Center(
        child: Text(
          '${widget.count}',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
    );

    if (changed) {
      badge = badge.animate(key: ValueKey(widget.count)).scale(
            duration: 200.ms,
            begin: const Offset(1, 1),
            end: const Offset(1.15, 1.15),
          ).then().scale(
            duration: 100.ms,
            begin: const Offset(1.15, 1.15),
            end: const Offset(1, 1),
          );
    }
    return badge;
  }
}
