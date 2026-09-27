class AdminUserOption {
  const AdminUserOption({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final String role;

  factory AdminUserOption.fromJson(Map<String, dynamic> json) =>
      AdminUserOption(
        id: json['id'].toString(),
        name: (json['name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        role: (json['role'] ?? '') as String,
      );
}
