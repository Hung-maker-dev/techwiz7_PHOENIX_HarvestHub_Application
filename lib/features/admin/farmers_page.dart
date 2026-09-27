// lib/features/admin/farmers_page.dart
// Route: /admin/farmers (NGUOI_5_MOBILE.md, 4.3)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../models/admin/admin_farmer.dart';
import '../../providers/admin/admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/farmer_list_tile.dart';
import 'widgets/status_filter_tabs.dart';
import 'admin_localization.dart';

class AdminFarmersPage extends ConsumerStatefulWidget {
  const AdminFarmersPage({super.key, this.initialStatus});

  /// Cho phép Dashboard (4.1) điều hướng thẳng vào tab đã lọc sẵn qua
  /// route '/admin/farmers?status=pending' (PendingActionsList).
  final FarmerStatus? initialStatus;

  @override
  ConsumerState<AdminFarmersPage> createState() => _AdminFarmersPageState();
}

class _AdminFarmersPageState extends ConsumerState<AdminFarmersPage> {
  /// Đang xử lý (đã bấm Duyệt/Từ chối, chờ animation #11 chạy xong) —
  /// dùng để tạm ẩn nút hành động trên thẻ và tránh double-tap trong lúc
  /// AnimatedSize đang thu gọn thẻ về 0.
  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialStatus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(farmerStatusFilterProvider.notifier).state =
            widget.initialStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmersAsync = ref.watch(farmersProvider);
    final statusFilter = ref.watch(farmerStatusFilterProvider);
    final actions = ref.read(farmerActionsProvider);

    return AdminShell(
      currentRoute: '/admin/farmers',
      title: adminText(context, 'Nông dân'), // i18n: admin.farmers.title
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: StatusFilterTabs<FarmerStatus?>(
              selected: statusFilter,
              onSelected: (v) =>
                  ref.read(farmerStatusFilterProvider.notifier).state = v,
              options: [
                StatusFilterOption('Tất cả', null),
                StatusFilterOption('Chờ duyệt', FarmerStatus.pending),
                StatusFilterOption('Đã duyệt', FarmerStatus.approved),
                StatusFilterOption('Từ chối', FarmerStatus.rejected),
              ],
            ),
          ),
          Expanded(
            child: farmersAsync.when(
              loading: () => Shimmer.fromColors(
                baseColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                highlightColor: Theme.of(context).colorScheme.surface,
                child: ListView.builder(
                  itemCount: 6,
                  itemBuilder: (_, __) => Container(
                    height: 96,
                    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              error: (err, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(farmersProvider),
                  child: Text(
                      adminText(context, 'Không tải được danh sách — thử lại')),
                ),
              ),
              data: (farmers) {
                if (farmers.isEmpty) {
                  return Center(
                      child:
                          Text(adminText(context, 'Không có nông dân nào.')));
                }
                return ListView.builder(
                  itemCount: farmers.length,
                  itemBuilder: (context, index) {
                    final f = farmers[index];
                    final isRemoving = _removing.contains(f.id);
                    // Pattern #11: thẻ vừa Duyệt/Từ chối thu gọn chiều cao
                    // về 0 + fade (~250ms) thay vì biến mất đột ngột. Bọc
                    // TỪNG item trong AnimatedSize, không rebuild lại toàn
                    // ListView.
                    return AnimatedSize(
                      duration: Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: 250),
                        opacity: isRemoving ? 0 : 1,
                        child: isRemoving
                            ? SizedBox.shrink()
                            : FarmerListTile(
                                farmer: f,
                                onApprove: () => _handleApprove(f, actions),
                                onReject: () => _handleReject(f, actions),
                                onToggleLock: (locked) =>
                                    _handleToggleLock(f, locked, actions),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(
      AdminFarmer f, FarmerActionsNotifier actions) async {
    // Chỉ chạy hiệu ứng rời-khỏi-danh-sách khi đang ở tab lọc "Chờ duyệt"
    // hoặc "Tất cả" (thẻ sẽ đổi badge tại chỗ, không biến mất) — theo đúng
    // ngữ cảnh mô tả 4.3 & pattern #11 ("rời khỏi tab Chờ duyệt").
    final onlyPendingTab =
        ref.read(farmerStatusFilterProvider) == FarmerStatus.pending;
    if (onlyPendingTab) setState(() => _removing.add(f.id));
    try {
      final emailSent = await actions.approve(f.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminText(
              context,
              emailSent
                  ? 'Đã duyệt hồ sơ và gửi email thông báo.'
                  : 'Đã duyệt hồ sơ nhưng chưa gửi được email thông báo.',
            )),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Farmer approval failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                adminText(context, 'Không thể duyệt hồ sơ. Vui lòng thử lại.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _removing.remove(f.id));
    }
  }

  Future<void> _handleReject(
      AdminFarmer f, FarmerActionsNotifier actions) async {
    final onlyPendingTab =
        ref.read(farmerStatusFilterProvider) == FarmerStatus.pending;
    if (onlyPendingTab) setState(() => _removing.add(f.id));
    try {
      await actions.reject(f.id);
    } finally {
      if (mounted) setState(() => _removing.remove(f.id));
    }
  }

  Future<void> _handleToggleLock(
    AdminFarmer farmer,
    bool locked,
    FarmerActionsNotifier actions,
  ) async {
    try {
      await actions.toggleLock(farmer.id, locked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(locked ? 'Đã khóa tài khoản.' : 'Đã mở khóa tài khoản.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(adminText(
                context, 'Không thể cập nhật trạng thái tài khoản.'))),
      );
    }
  }
}
