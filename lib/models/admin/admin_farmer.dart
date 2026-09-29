enum FarmerStatus { pending, approved, rejected }

FarmerStatus farmerStatusFromString(String value) {
  switch (value) {
    case 'pending':
      return FarmerStatus.pending;
    case 'rejected':
      return FarmerStatus.rejected;
    case 'approved':
    default:
      return FarmerStatus.approved;
  }
}

String farmerStatusToString(FarmerStatus s) => s.name;

class AdminFarmer {
  final String id;
  final String farmName;
  final String? marketId;
  final String? marketName;
  final FarmerStatus status;
  final bool isLocked;
  final double rating;
  final int ratingCount;
  final int followerCount;
  final String? description;
  final String? avatarUrl;
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPhone;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  const AdminFarmer({
    required this.id,
    required this.farmName,
    this.marketId,
    this.marketName,
    required this.status,
    required this.isLocked,
    required this.rating,
    required this.ratingCount,
    required this.followerCount,
    this.description,
    this.avatarUrl,
    this.ownerName,
    this.ownerEmail,
    this.ownerPhone,
    this.address,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory AdminFarmer.fromJson(Map<String, dynamic> json) => AdminFarmer(
        id: json['id'].toString(),
        farmName: (json['farmName'] ?? json['farm_name'] ?? '') as String,
        marketId: (json['marketId'] ?? json['market_id'])?.toString(),
        marketName: (json['marketName'] ?? json['market_name']) as String?,
        status: farmerStatusFromString((json['status'] ?? 'pending') as String),
        isLocked: (json['isLocked'] ?? json['is_locked'] ?? false) as bool,
        rating: _parseFarmerNumber(json['rating']) ?? 0,
        ratingCount: (json['ratingCount'] ?? json['rating_count'] ?? 0) as int,
        followerCount:
            (json['followerCount'] ?? json['follower_count'] ?? 0) as int,
        description: json['description'] as String?,
        avatarUrl: (json['avatarUrl'] ?? json['avatar_url']) as String?,
        ownerName: (json['ownerName'] ?? json['owner_name']) as String?,
        ownerEmail: (json['ownerEmail'] ?? json['owner_email']) as String?,
        ownerPhone: (json['ownerPhone'] ?? json['owner_phone']) as String?,
        address: json['address'] as String?,
        latitude: _parseFarmerNumber(json['latitude']),
        longitude: _parseFarmerNumber(json['longitude']),
        createdAt:
            DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
      );

  AdminFarmer copyWith({FarmerStatus? status, bool? isLocked}) => AdminFarmer(
        id: id,
        farmName: farmName,
        marketId: marketId,
        marketName: marketName,
        status: status ?? this.status,
        isLocked: isLocked ?? this.isLocked,
        rating: rating,
        ratingCount: ratingCount,
        followerCount: followerCount,
        description: description,
        avatarUrl: avatarUrl,
        ownerName: ownerName,
        ownerEmail: ownerEmail,
        ownerPhone: ownerPhone,
        address: address,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
      );
}

double? _parseFarmerNumber(Object? value) =>
    value == null ? null : double.tryParse(value.toString());
