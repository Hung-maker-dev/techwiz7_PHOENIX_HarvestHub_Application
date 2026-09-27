// lib/features/admin/widgets/filter_bottom_sheet.dart
//
// Khung `FilterBottomSheet` dùng chung cho 4.4 (nông dân/danh mục/trạng
// thái), 4.7 (trạng thái/chợ/khoảng thời gian) và 4.10 (người thực hiện/
// khoảng thời gian) — mỗi màn tự truyền `child` là form field riêng, khung
// chỉ lo phần bottom-sheet + nút Áp dụng/Đặt lại (pattern #3: mọi bộ lọc
// trên mobile quy về `showModalBottomSheet`).

import 'package:flutter/material.dart';
import '../admin_localization.dart';

Future<void> showAppFilterSheet(
  BuildContext context, {
  required String title,
  required Widget child,
  required VoidCallback onApply,
  VoidCallback? onReset,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 16),
          child,
          SizedBox(height: 20),
          Row(
            children: [
              if (onReset != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      onReset();
                      Navigator.of(context).pop();
                    },
                    child: Text(adminText(context, 'Đặt lại')),
                  ),
                ),
              if (onReset != null) SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    onApply();
                    Navigator.of(context).pop();
                  },
                  child: Text(adminText(context, 'Áp dụng')),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
