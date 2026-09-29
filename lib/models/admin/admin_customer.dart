class AdminCustomer {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String authProvider; // 'password' | 'google'
  final String preferredLanguage; // 'vi' | 'en'
  final DateTime createdAt;
  final bool isLocked;
  // Chỉ có khi gọi chi tiết (GET /api/admin/customers/:id) — null ở list.
  final int? orderCount;
  final double? totalSpent;

  const AdminCustomer({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.authProvider,
    required this.preferredLanguage,
    required this.createdAt,
    required this.isLocked,
    this.orderCount,
    this.totalSpent,
  });

  factory AdminCustomer.fromJson(Map<String, dynamic> json) => AdminCustomer(
        id: json['id'].toString(),
        name: (json['name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        phone: json['phone'] as String?,
        avatarUrl: (json['avatarUrl'] ?? json['avatar_url']) as String?,
        authProvider: (json['authProvider'] ??
            json['auth_provider'] ??
            'password') as String,
        preferredLanguage: (json['preferredLanguage'] ??
            json['preferred_language'] ??
            'vi') as String,
        createdAt:
            DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
        isLocked: (json['isLocked'] ?? json['is_locked'] ?? false) as bool,
        orderCount: _toInt(json['orderCount'] ?? json['order_count']),
        totalSpent: _toDouble(json['totalSpent'] ?? json['total_spent']),
      );

  static int? _toInt(Object? value) =>
      value == null ? null : int.tryParse(value.toString());

  static double? _toDouble(Object? value) =>
      value == null ? null : double.tryParse(value.toString());
}
