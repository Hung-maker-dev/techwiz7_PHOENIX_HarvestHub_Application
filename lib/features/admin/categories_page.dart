import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin/admin_category.dart';
import '../../providers/admin/admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/category_form_sheet.dart';
import 'admin_localization.dart';

class AdminCategoriesPage extends ConsumerStatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  ConsumerState<AdminCategoriesPage> createState() =>
      _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends ConsumerState<AdminCategoriesPage> {
  List<AdminCategory>? _localOrder;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final actions = ref.read(categoryActionsProvider);

    ref.listen(categoriesProvider, (prev, next) {
      next.whenData((data) => setState(() => _localOrder = List.of(data)));
    });

    return AdminShell(
      currentRoute: '/admin/categories',
      title: adminText(context, 'Danh mục'), // i18n: admin.categories.title
      actions: [
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () async {
            final draft = await showCategoryFormSheet(context);
            if (draft != null) await actions.create(draft);
          },
        ),
      ],
      child: categoriesAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(categoriesProvider),
            child:
                Text(adminText(context, 'Không tải được danh mục — thử lại')),
          ),
        ),
        data: (data) {
          final items = _localOrder ?? data;
          if (items.isEmpty) {
            return Center(
                child: Text(adminText(context, 'Chưa có danh mục nào.')));
          }
          return ReorderableListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                final list = List.of(items);
                if (newIndex > oldIndex) newIndex -= 1;
                final moved = list.removeAt(oldIndex);
                list.insert(newIndex, moved);
                _localOrder = [
                  for (var i = 0; i < list.length; i++)
                    list[i].copyWith(displayOrder: i),
                ];
              });
              actions.reorder([for (final c in _localOrder!) c.id]);
            },
            itemBuilder: (context, index) {
              final c = items[index];
              return ListTile(
                key: ValueKey(c.id),
                leading: Icon(Icons.drag_handle),
                title: Text(c.name),
                subtitle: Text(c.nameEn ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!c.isActive)
                      Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Chip(
                            label: Text(adminText(context, 'Ẩn')),
                            visualDensity: VisualDensity.compact),
                      ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final draft =
                            await showCategoryFormSheet(context, existing: c);
                        if (draft != null) await actions.update(c.id, draft);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, actions, c),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CategoryActionsNotifier actions,
    AdminCategory c,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(adminText(context, 'Xoá danh mục?')),
        content: Text(adminText(context, 'Xoá "${c.name}" khỏi hệ thống?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(adminText(context, 'Huỷ')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(adminText(context, 'Xoá')),
          ),
        ],
      ),
    );
    if (confirmed == true) await actions.remove(c.id);
  }
}
