import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin/admin_account.dart';
import '../../providers/admin/admin_providers.dart';
import 'admin_localization.dart';
import 'admin_shell.dart';
import 'widgets/status_filter_tabs.dart';

class AdminAccountsPage extends ConsumerStatefulWidget {
  const AdminAccountsPage({super.key});

  @override
  ConsumerState<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends ConsumerState<AdminAccountsPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  final Set<String> _busyAccounts = {};

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(accountSearchQueryProvider.notifier).state = value.trim();
    });
  }

  Future<void> _reviewFarmer(AdminAccount account,
      {required bool approve}) async {
    final farmerId = account.farmerId;
    if (farmerId == null || _busyAccounts.contains(account.id)) return;
    final actionLabel = adminText(context, approve ? 'Duyệt' : 'Từ chối');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$actionLabel ${adminText(context, 'hồ sơ farmer')}?'),
        content: Text(
          '${account.farmName ?? account.name} (${account.email})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(adminText(context, 'Huỷ')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyAccounts.add(account.id));
    try {
      final actions = ref.read(farmerActionsProvider);
      if (approve) {
        final emailSent = await actions.approve(farmerId);
        if (!mounted) return;
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
      } else {
        await actions.reject(farmerId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(adminText(context, 'Đã từ chối hồ sơ.'))),
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
          'Could not review farmer account ${account.id}: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminText(
                context, 'Không thể cập nhật hồ sơ. Vui lòng thử lại.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAccounts.remove(account.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(adminAccountsProvider);
    final type = ref.watch(accountTypeFilterProvider);
    final status = ref.watch(accountStatusFilterProvider);

    return AdminShell(
      currentRoute: '/admin/accounts',
      title: adminText(context, 'Tài khoản'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText:
                    adminText(context, 'Tìm theo tên, email hoặc trang trại'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          _FilterRow<String>(
            label: adminText(context, 'Loại tài khoản'),
            selected: type,
            options: const [
              ('Tất cả', 'all'),
              ('Khách hàng', 'customer'),
              ('Nông dân', 'farmer'),
            ],
            onSelected: (value) =>
                ref.read(accountTypeFilterProvider.notifier).state = value,
          ),
          _FilterRow<String>(
            label: adminText(context, 'Trạng thái duyệt'),
            selected: status,
            options: const [
              ('Tất cả', 'all'),
              ('Chờ duyệt', 'pending'),
              ('Đã duyệt', 'approved'),
              ('Từ chối', 'rejected'),
              ('Không yêu cầu duyệt', 'not_applicable'),
            ],
            onSelected: (value) =>
                ref.read(accountStatusFilterProvider.notifier).state = value,
          ),
          Expanded(
            child: accounts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) {
                debugPrint(
                    'Could not load admin accounts: $error\n$stackTrace');
                return Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(adminAccountsProvider),
                    child: Text(adminText(
                        context, 'Không tải được danh sách — thử lại')),
                  ),
                );
              },
              data: (items) => items.isEmpty
                  ? Center(
                      child: Text(
                          adminText(context, 'Không tìm thấy tài khoản nào.')),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(adminAccountsProvider.future),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) {
                          final account = items[index];
                          return _AccountTile(
                            account: account,
                            isBusy: _busyAccounts.contains(account.id),
                            onApprove: () =>
                                _reviewFarmer(account, approve: true),
                            onReject: () =>
                                _reviewFarmer(account, approve: false),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow<T> extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final T selected;
  final List<(String, T)> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            StatusFilterTabs<T>(
              selected: selected,
              onSelected: onSelected,
              options: [
                for (final option in options)
                  StatusFilterOption(
                    adminText(context, option.$1),
                    option.$2,
                  ),
              ],
            ),
          ],
        ),
      );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final AdminAccount account;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isFarmer = account.accountType == 'farmer';
    final statusLabel = switch (account.applicationStatus) {
      'pending' => 'Chờ duyệt',
      'approved' => 'Đã duyệt',
      'rejected' => 'Từ chối',
      _ => 'Không yêu cầu duyệt',
    };
    final statusColor = switch (account.applicationStatus) {
      'pending' => Colors.orange,
      'approved' => Colors.green,
      'rejected' => Colors.red,
      _ => Theme.of(context).colorScheme.outline,
    };
    return ListTile(
      leading: CircleAvatar(
        child:
            Icon(isFarmer ? Icons.agriculture_outlined : Icons.person_outline),
      ),
      title: Text(account.name.isEmpty ? account.email : account.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(account.email),
          if (account.phone?.isNotEmpty == true) Text(account.phone!),
          if (account.farmName?.isNotEmpty == true)
            Text('${adminText(context, 'Trang trại')}: ${account.farmName}'),
          if (account.marketName?.isNotEmpty == true)
            Text('${adminText(context, 'Chợ')}: ${account.marketName}'),
          if (account.farmAddress?.isNotEmpty == true)
            Text('${adminText(context, 'Địa chỉ')}: ${account.farmAddress}'),
          if (account.latitude != null && account.longitude != null)
            Text(
              '${adminText(context, 'Tọa độ GPS')}: '
              '${account.latitude!.toStringAsFixed(6)}, '
              '${account.longitude!.toStringAsFixed(6)}',
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _AccountBadge(
                label: adminText(context, isFarmer ? 'Nông dân' : 'Khách hàng'),
                color: isFarmer ? Colors.teal : Colors.blue,
              ),
              _AccountBadge(
                label: adminText(context, statusLabel),
                color: statusColor,
              ),
            ],
          ),
          if (account.applicationStatus == 'pending' &&
              account.farmerId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isBusy ? null : onReject,
                    child: Text(adminText(context, 'Từ chối')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : onApprove,
                    icon: isBusy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(adminText(context, 'Duyệt')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      isThreeLine: true,
      trailing:
          account.isLocked ? const Icon(Icons.lock_outline, size: 18) : null,
    );
  }
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 11),
        ),
      );
}
