enum ContactMessageStatus { pending, resolved }

ContactMessageStatus contactStatusFromString(String value) =>
    value == 'resolved'
        ? ContactMessageStatus.resolved
        : ContactMessageStatus.pending;

class AdminContactMessage {
  final String id;
  final String name;
  final String email;
  final String subject;
  final String message;
  final ContactMessageStatus status;
  final DateTime createdAt;

  const AdminContactMessage({
    required this.id,
    required this.name,
    required this.email,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory AdminContactMessage.fromJson(Map<String, dynamic> json) =>
      AdminContactMessage(
        id: json['id'].toString(),
        name: (json['name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        subject: (json['subject'] ?? '') as String,
        message: (json['message'] ?? '') as String,
        status:
            contactStatusFromString((json['status'] ?? 'pending') as String),
        createdAt:
            DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
      );

  AdminContactMessage copyWith({ContactMessageStatus? status}) =>
      AdminContactMessage(
        id: id,
        name: name,
        email: email,
        subject: subject,
        message: message,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
