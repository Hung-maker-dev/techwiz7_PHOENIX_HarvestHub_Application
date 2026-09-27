class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.accountType,
    required this.applicationStatus,
    required this.createdAt,
    required this.isLocked,
    this.farmerId,
    this.phone,
    this.farmName,
    this.marketName,
    this.farmAddress,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String accountType;
  final String applicationStatus;
  final DateTime createdAt;
  final bool isLocked;
  final String? farmerId;
  final String? phone;
  final String? farmName;
  final String? marketName;
  final String? farmAddress;
  final double? latitude;
  final double? longitude;

  factory AdminAccount.fromJson(Map<String, dynamic> json) => AdminAccount(
        id: json['id'].toString(),
        name: (json['name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        role: (json['role'] ?? '') as String,
        accountType: (json['account_type'] ?? 'customer') as String,
        applicationStatus:
            (json['application_status'] ?? 'not_applicable') as String,
        createdAt: DateTime.parse((json['created_at'] ?? '') as String),
        isLocked: json['is_locked'] == true ||
            json['is_locked'] == 1 ||
            json['is_locked'] == '1',
        farmerId: json['farmer_id']?.toString(),
        phone: json['phone'] as String?,
        farmName: json['farm_name'] as String?,
        marketName: json['market_name'] as String?,
        farmAddress: json['farm_address'] as String?,
        latitude: _toCoordinate(json['latitude']),
        longitude: _toCoordinate(json['longitude']),
      );

  static double? _toCoordinate(Object? value) =>
      value == null ? null : double.tryParse(value.toString());
}
