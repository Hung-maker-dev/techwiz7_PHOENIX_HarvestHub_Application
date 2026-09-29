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
        createdAt:
            DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
      );
}
