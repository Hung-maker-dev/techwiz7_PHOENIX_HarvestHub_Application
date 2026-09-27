import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/network/dio_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared_widgets/app_card.dart';
import '../../shared_widgets/app_skeleton.dart';

class NearbyMarketsPage extends ConsumerStatefulWidget {
  const NearbyMarketsPage({super.key});

  @override
  ConsumerState<NearbyMarketsPage> createState() => _NearbyMarketsPageState();
}

class _NearbyMarketsPageState extends ConsumerState<NearbyMarketsPage> {
  Position? _position;
  List<_NearbyMarket> _markets = const [];
  _NearbyMarket? _selectedMarket;
  List<LatLng> _routePoints = const [];
  double? _routeDistanceKm;
  double? _routeDurationMinutes;
  String _searchQuery = '';
  String? _error;
  String? _routeError;
  bool _loading = true;
  bool _routing = false;

  @override
  void initState() {
    super.initState();
    _loadMarkets();
  }

  Future<void> _loadMarkets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final position = await _getPosition();
      final response = await ref.read(dioProvider).get(
            '/api/nearby-markets',
            queryParameters: {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'radius': 10000,
            },
            options: Options(
              sendTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 25),
            ),
          );
      final rows = (response.data['data'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((row) => _NearbyMarket.fromJson(row, position))
          .whereType<_NearbyMarket>()
          .toList()
        ..sort(
            (first, second) => first.distanceKm.compareTo(second.distanceKm));
      if (mounted) {
        setState(() {
          _position = position;
          _markets = rows;
          _selectedMarket = null;
          _routePoints = const [];
          _routeDistanceKm = null;
          _routeDurationMinutes = null;
          _routeError = null;
        });
      }
    } on DioException catch (error) {
      debugPrint(
        'Nearby markets failed: status=${error.response?.statusCode}, '
        'type=${error.type}, message=${error.message}',
      );
      if (mounted) {
        final status = error.response?.statusCode;
        setState(() {
          _error = status == null
              ? 'Không kết nối được API. Hãy kiểm tra API_BASE_URL, '
                  'PHP server và kết nối mạng.'
              : 'Backend trả lỗi HTTP $status. Hãy khởi động lại PHP server.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Hãy bật dịch vụ vị trí trên điện thoại.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Ứng dụng cần quyền vị trí để tìm chợ gần bạn.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  List<_NearbyMarket> get _filteredMarkets {
    final normalized = _searchQuery.trim().toLowerCase();
    if (normalized.isEmpty) return _markets;
    return _markets
        .where((market) => '${market.name} ${market.address}'
            .toLowerCase()
            .contains(normalized))
        .toList();
  }

  Future<void> _selectMarket(_NearbyMarket market) async {
    final position = _position;
    if (position == null) return;
    setState(() {
      _selectedMarket = market;
      _routePoints = const [];
      _routeDistanceKm = null;
      _routeDurationMinutes = null;
      _routeError = null;
      _routing = true;
    });

    try {
      final response = await ref.read(dioProvider).get(
            '/api/route',
            queryParameters: {
              'from_lat': position.latitude,
              'from_lng': position.longitude,
              'to_lat': market.latitude,
              'to_lng': market.longitude,
            },
            options: Options(
              sendTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 35),
            ),
          );
      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Dữ liệu tuyến đường không hợp lệ.');
      }
      final route = _parseRoute(payload);
      if (route == null) {
        throw const FormatException('Không tìm thấy tuyến đường đến chợ này.');
      }
      if (mounted && _selectedMarket?.id == market.id) {
        setState(() {
          _routePoints = route.points;
          _routeDistanceKm = route.distanceMeters / 1000;
          _routeDurationMinutes = route.durationSeconds / 60;
        });
      }
    } on DioException catch (error) {
      debugPrint(
        'Market route failed: status=${error.response?.statusCode}, '
        'type=${error.type}, message=${error.message}',
      );
      if (mounted && _selectedMarket?.id == market.id) {
        setState(() {
          _routeError = error.response?.statusCode == null
              ? 'Không kết nối được dịch vụ chỉ đường. Hãy kiểm tra backend và OSRM.'
              : error.response?.statusCode == 502
                  ? 'PHP API không gọi được OSRM (HTTP 502). '
                      'Kiểm tra OSRM_BASE_URL và OSRM từ máy/container chạy PHP.'
                  : 'Dịch vụ chỉ đường trả lỗi HTTP ${error.response?.statusCode}.';
        });
      }
    } on FormatException catch (error) {
      if (mounted && _selectedMarket?.id == market.id) {
        setState(() => _routeError = error.message);
      }
    } finally {
      if (mounted && _selectedMarket?.id == market.id) {
        setState(() => _routing = false);
      }
    }
  }

  _MarketRoute? _parseRoute(Map<String, dynamic> payload) {
    final routes = payload['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      return null;
    }
    final route = Map<String, dynamic>.from(routes.first as Map);
    final geometry = route['geometry'];
    final coordinates =
        geometry is Map<String, dynamic> ? geometry['coordinates'] : null;
    final distance = route['distance'];
    final duration = route['duration'];
    if (coordinates is! List || distance is! num || duration is! num) {
      return null;
    }

    final points = <LatLng>[];
    for (final coordinate in coordinates) {
      if (coordinate is! List || coordinate.length < 2) return null;
      final longitude = coordinate[0];
      final latitude = coordinate[1];
      if (longitude is! num ||
          latitude is! num ||
          longitude < -180 ||
          longitude > 180 ||
          latitude < -90 ||
          latitude > 90) {
        return null;
      }
      points.add(LatLng(latitude.toDouble(), longitude.toDouble()));
    }
    if (points.length < 2 || distance < 0 || duration < 0) return null;
    return _MarketRoute(
      points: points,
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    final markets = _filteredMarkets;
    return Scaffold(
      appBar: AppBar(title: const Text('Chợ gần tôi')),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(AppSpace.space3),
              itemCount: 3,
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.only(bottom: AppSpace.space2),
                child: AppSkeleton(variant: AppSkeletonVariant.card),
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.space3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpace.space2),
                        ElevatedButton(
                            onPressed: _loadMarkets,
                            child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : position == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpace.space2,
                              AppSpace.space2, AppSpace.space2, 0),
                          child: TextField(
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            decoration: const InputDecoration(
                              labelText: 'Tìm chợ gần đây',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter:
                                  LatLng(position.latitude, position.longitude),
                              initialZoom: 11,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.harvesthub.harvesthub_mobile',
                              ),
                              if (_routePoints.isNotEmpty)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: _routePoints,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      strokeWidth: 5,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(
                                        position.latitude, position.longitude),
                                    width: 44,
                                    height: 44,
                                    child: const Icon(Icons.my_location,
                                        color: Colors.blue, size: 32),
                                  ),
                                  ...markets.map(
                                    (market) => Marker(
                                      point: LatLng(
                                          market.latitude, market.longitude),
                                      width: 44,
                                      height: 44,
                                      child: GestureDetector(
                                        onTap: () => _selectMarket(market),
                                        child: Icon(
                                          Icons.location_on,
                                          color:
                                              _selectedMarket?.id == market.id
                                                  ? Colors.deepOrange
                                                  : Colors.red,
                                          size: 36,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_routing || _routeError != null)
                                Positioned(
                                  top: AppSpace.space2,
                                  left: AppSpace.space2,
                                  right: AppSpace.space2,
                                  child: Material(
                                    elevation: 2,
                                    borderRadius: BorderRadius.circular(12),
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.all(AppSpace.space2),
                                      child: _routing
                                          ? const Row(
                                              children: [
                                                SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2),
                                                ),
                                                SizedBox(
                                                    width: AppSpace.space2),
                                                Text('Đang tìm đường...'),
                                              ],
                                            )
                                          : Text(
                                              _routeError!,
                                              textAlign: TextAlign.center,
                                            ),
                                    ),
                                  ),
                                ),
                              const RichAttributionWidget(
                                attributions: [
                                  TextSourceAttribution(
                                      'OpenStreetMap contributors'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpace.space2),
                            itemCount: markets.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpace.space2),
                            itemBuilder: (context, index) {
                              final market = markets[index];
                              return AppCard(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading:
                                      const Icon(Icons.storefront_outlined),
                                  title: Text(market.name),
                                  subtitle: Text(
                                    '${market.distanceKm.toStringAsFixed(1)} km'
                                    '${_selectedMarket?.id == market.id && _routeDistanceKm != null ? ' · Tuyến ${_routeDistanceKm!.toStringAsFixed(1)} km, khoảng ${_routeDurationMinutes!.round()} phút' : ''}'
                                    '\n${market.address}',
                                  ),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    tooltip: 'Vẽ đường trên bản đồ',
                                    icon: Icon(
                                      Icons.directions,
                                      color: _selectedMarket?.id == market.id
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                    ),
                                    onPressed: () => _selectMarket(market),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _MarketRoute {
  const _MarketRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

class _NearbyMarket {
  const _NearbyMarket({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceKm;

  static _NearbyMarket? fromJson(Map<String, dynamic> json, Position position) {
    final latitude = double.tryParse('${json['latitude']}');
    final longitude = double.tryParse('${json['longitude']}');
    if (latitude == null || longitude == null) return null;
    return _NearbyMarket(
      id: '${json['id'] ?? json['name']}',
      name: '${json['name'] ?? ''}',
      address: '${json['address'] ?? ''}',
      latitude: latitude,
      longitude: longitude,
      distanceKm: _distanceKm(
          position.latitude, position.longitude, latitude, longitude),
    );
  }

  static double _distanceKm(
      double fromLat, double fromLng, double toLat, double toLng) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(toLat - fromLat);
    final dLng = _radians(toLng - fromLng);
    final value = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(fromLat)) *
            math.cos(_radians(toLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm *
        2 *
        math.atan2(math.sqrt(value), math.sqrt(1 - value));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
