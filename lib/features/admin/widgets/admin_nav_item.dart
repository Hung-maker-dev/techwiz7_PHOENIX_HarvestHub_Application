// lib/features/admin/widgets/admin_nav_item.dart
//
// Pattern #9 (ANIMATION_SYSTEM_MOBILE.md), nhánh Drawer: "thanh dọc màu
// primary bên trái mục đang chọn, cùng cơ chế animate [trượt theo]", áp
// dụng cho `Drawer` danh sách dọc của admin (10 mục — theo quyết định ở
// đầu NGUOI_5_MOBILE.md, KHÔNG dùng BottomNavigationBar). 200ms theo cùng
// pattern #9. Dùng `AnimatedContainer` (vi tương tác, không cần
// AnimationController thủ công) thay vì flutter_animate cho hiệu ứng đơn
// giản này.

import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

class AdminNavItem extends StatelessWidget {
  const AdminNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppDurations.micro,
              width: 3,
              height: selected ? 28 : 0,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 13),
            Icon(
              icon,
              size: 20,
              color:
                  selected ? theme.colorScheme.primary : theme.iconTheme.color,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: selected ? theme.colorScheme.primary : null,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
