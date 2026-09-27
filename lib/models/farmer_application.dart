class FarmerMarketOption {
  const FarmerMarketOption({
    required this.id,
    required this.name,
    this.address,
  });

  final String id;
  final String name;
  final String? address;

  factory FarmerMarketOption.fromJson(Map<String, dynamic> json) =>
      FarmerMarketOption(
        id: json['id'].toString(),
        name: (json['name'] ?? '') as String,
        address: json['address'] as String?,
      );
}

class FarmerApplication {
  const FarmerApplication({
    required this.status,
    required this.farmName,
    required this.marketId,
    this.marketName,
    this.marketAddress,
    this.contactPhone,
    this.address,
    this.description,
    this.latitude,
    this.longitude,
  });

  final String status;
  final String farmName;
  final String marketId;
  final String? marketName;
  final String? marketAddress;
  final String? contactPhone;
  final String? address;
  final String? description;
  final double? latitude;
  final double? longitude;

  factory FarmerApplication.fromJson(Map<String, dynamic> json) =>
      FarmerApplication(
        status: (json['status'] ?? 'pending') as String,
        farmName: (json['farm_name'] ?? '') as String,
        marketId: (json['market_id'] ?? '').toString(),
        marketName: json['market_name'] as String?,
        marketAddress: json['market_address'] as String?,
        contactPhone: json['contact_phone'] as String?,
        address: json['address'] as String?,
        description: json['description'] as String?,
        latitude: _toDouble(json['latitude']),
        longitude: _toDouble(json['longitude']),
      );
}

double? _toDouble(Object? value) =>
    value == null ? null : double.tryParse(value.toString());
