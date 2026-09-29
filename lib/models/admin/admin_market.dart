class AdminMarket {
  final String id;
  final String name;
  final String? nameEn;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? geohash;
  final String? openHours;
  final bool isActive;
  final int farmerCount;

  const AdminMarket({
    required this.id,
    required this.name,
    this.nameEn,
    this.address,
    this.latitude,
    this.longitude,
    this.geohash,
    this.openHours,
    required this.isActive,
    required this.farmerCount,
  });

  factory AdminMarket.fromJson(Map<String, dynamic> json) => AdminMarket(
        id: json['id'].toString(),
        name: (json['name'] ?? '') as String,
        nameEn: (json['nameEn'] ?? json['name_en']) as String?,
        address: json['address'] as String?,
        latitude: _toDouble(json['latitude']),
        longitude: _toDouble(json['longitude']),
        geohash: json['geohash'] as String?,
        openHours: (json['openHours'] ?? json['open_hours']) as String?,
        isActive: (json['isActive'] ?? json['is_active'] ?? true) as bool,
        farmerCount: _toInt(json['farmerCount'] ?? json['farmer_count']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'nameEn': nameEn,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'geohash': geohash,
        'openHours': openHours,
        'isActive': isActive,
      };
}

double? _toDouble(Object? value) =>
    value == null ? null : double.tryParse(value.toString());

int? _toInt(Object? value) =>
    value == null ? null : int.tryParse(value.toString());
