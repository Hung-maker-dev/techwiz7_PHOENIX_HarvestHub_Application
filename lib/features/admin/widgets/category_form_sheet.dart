// lib/features/admin/widgets/category_form_sheet.dart
//
// 4.5: `CategoryFormSheet` dùng chung cho tạo mới và sửa (truyền [existing]
// khi sửa). Bottom sheet theo pattern #3.

import 'package:flutter/material.dart';

import '../../../models/admin/admin_category.dart';
import '../admin_localization.dart';

Future<AdminCategory?> showCategoryFormSheet(
  BuildContext context, {
  AdminCategory? existing,
}) {
  return showModalBottomSheet<AdminCategory>(
    context: context,
    isScrollControlled: true,
    builder: (context) => CategoryFormSheet(existing: existing),
  );
}

class CategoryFormSheet extends StatefulWidget {
  CategoryFormSheet({super.key, this.existing});
  final AdminCategory? existing;

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _nameEnCtrl =
      TextEditingController(text: widget.existing?.nameEn ?? '');
  late bool _isActive = widget.existing?.isActive ?? true;

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'Sửa danh mục' : 'Thêm danh mục',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                  labelText: adminText(context, 'Tên (Tiếng Việt)')),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _nameEnCtrl,
              decoration: InputDecoration(
                  labelText: adminText(context, 'Tên (English)')),
            ),
            SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(adminText(context, 'Hiển thị trên Shop')),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(isEditing ? 'Lưu' : 'Thêm'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      AdminCategory(
        id: widget.existing?.id ?? '',
        name: _nameCtrl.text.trim(),
        nameEn:
            _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        displayOrder: widget.existing?.displayOrder ?? 0,
        isActive: _isActive,
      ),
    );
  }
}
