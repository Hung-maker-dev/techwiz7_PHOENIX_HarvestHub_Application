// lib/models/admin/audit_log_entry.dart
//
// Khớp bảng `audit_logs`, actor_id cho phép NULL từ
// harvesthub_mysql_migration.sql khối 6 (hành động hệ thống tự động: cron
// cảnh báo tồn kho thấp, job báo có hàng lại...). Khi actorId == null, UI
// hiển thị "Hệ thống" thay vì tên người dùng — xử lý ở `actorDisplayName`.
// Dùng cho GET /api/admin/audit-log?actor=&from=&to= (4.10, chỉ đọc).

class AuditLogEntry {
  final String id;
  final String? actorId;
  final String? actorName;
  final String action;
  final String entityType;
  final String entityId;
  final String? details;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    this.actorId,
    this.actorName,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.details,
    required this.createdAt,
  });

  String get actorDisplayName => actorId == null
      ? 'Hệ thống'
      : (actorName?.isNotEmpty == true ? actorName! : actorId!);

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'].toString(),
        actorId: (json['actorId'] ?? json['actor_id'])?.toString(),
        actorName: (json['actorName'] ?? json['actor_name']) as String?,
        action: (json['action'] ?? '') as String,
        entityType: (json['entityType'] ?? json['entity_type'] ?? '') as String,
        entityId: (json['entityId'] ?? json['entity_id'] ?? '').toString(),
        details: json['details'] as String?,
        createdAt: DateTime.parse(
            (json['createdAt'] ?? json['created_at']) as String),
      );
}
