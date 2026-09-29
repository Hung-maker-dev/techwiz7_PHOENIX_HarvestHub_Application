import 'package:flutter/material.dart';

import '../../../models/admin/admin_farmer.dart';
import '../admin_localization.dart';

class FarmerListTile extends StatelessWidget {
  const FarmerListTile({
    super.key,
    required this.farmer,
    required this.onApprove,
    required this.onReject,
    required this.onToggleLock,
    this.onTap,
  });

  final AdminFarmer farmer;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final ValueChanged<bool> onToggleLock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: farmer.avatarUrl != null
                        ? NetworkImage(farmer.avatarUrl!)
                        : null,
                    child: farmer.avatarUrl == null
                        ? Text(farmer.farmName.isNotEmpty
                            ? farmer.farmName[0].toUpperCase()
                            : '?')
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(farmer.farmName,
                            style: theme.textTheme.titleMedium),
                        Text(
                          farmer.marketName ?? '—',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: farmer.status),
                ],
              ),
            ),
            if (farmer.ownerName?.isNotEmpty == true ||
                farmer.ownerEmail?.isNotEmpty == true ||
                farmer.ownerPhone?.isNotEmpty == true ||
                farmer.address?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              if (farmer.ownerName?.isNotEmpty == true)
                _FarmerDetail(
                    icon: Icons.person_outline, text: farmer.ownerName!),
              if (farmer.ownerEmail?.isNotEmpty == true)
                _FarmerDetail(
                    icon: Icons.email_outlined, text: farmer.ownerEmail!),
              if (farmer.ownerPhone?.isNotEmpty == true)
                _FarmerDetail(
                    icon: Icons.phone_outlined, text: farmer.ownerPhone!),
              if (farmer.address?.isNotEmpty == true)
                _FarmerDetail(
                    icon: Icons.place_outlined, text: farmer.address!),
              if (farmer.latitude != null && farmer.longitude != null)
                _FarmerDetail(
                  icon: Icons.my_location,
                  text:
                      '${farmer.latitude!.toStringAsFixed(6)}, ${farmer.longitude!.toStringAsFixed(6)}',
                ),
            ],
            if (farmer.status == FarmerStatus.pending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      child: Text(adminText(context, 'Từ chối')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onApprove,
                      child: Text(adminText(context, 'Duyệt')),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(adminText(context, 'Khoá tài khoản')),
                  Switch(value: farmer.isLocked, onChanged: onToggleLock),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FarmerDetail extends StatelessWidget {
  const _FarmerDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: Theme.of(context).hintColor),
            const SizedBox(width: 8),
            Expanded(
                child:
                    Text(text, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final FarmerStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      FarmerStatus.pending => ('Chờ duyệt', Colors.orange),
      FarmerStatus.approved => ('Đã duyệt', Colors.green),
      FarmerStatus.rejected => ('Từ chối', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
