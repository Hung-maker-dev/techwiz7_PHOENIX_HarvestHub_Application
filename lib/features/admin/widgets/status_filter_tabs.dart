// lib/features/admin/widgets/status_filter_tabs.dart
//
// Widget con dùng chung nội bộ module admin cho 4.3 (Tất cả/Chờ duyệt/Đã
// duyệt/Từ chối) và 4.8 (Mới/Đã xử lý) — generic theo danh sách label/value
// để không viết trùng 2 lần. Đây KHÔNG phải widget "nguyên liệu" chuyển
// vào shared_widgets/ vì chỉ admin dùng.

import 'package:flutter/material.dart';

class StatusFilterTabs<T> extends StatelessWidget {
  const StatusFilterTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<StatusFilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option.value == selected;
          return ChoiceChip(
            label: Text(option.label),
            selected: isSelected,
            onSelected: (_) => onSelected(option.value),
          );
        },
      ),
    );
  }
}

class StatusFilterOption<T> {
  const StatusFilterOption(this.label, this.value);
  final String label;
  final T value;
}
