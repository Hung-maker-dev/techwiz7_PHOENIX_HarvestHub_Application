import 'package:flutter/material.dart';
import '../admin_localization.dart';

Future<String?> showHideProductDialog(
  BuildContext context, {
  required String productName,
}) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(adminText(context, 'Ẩn "$productName"')),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: adminText(context, 'Lý do ẩn sản phẩm'),
            hintText: adminText(context, 'Vd: nội dung/mô tả vi phạm quy định'),
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Vui lòng nhập lý do'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(adminText(context, 'Huỷ')),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(controller.text.trim());
            }
          },
          child: Text(adminText(context, 'Xác nhận ẩn')),
        ),
      ],
    ),
  );
}
