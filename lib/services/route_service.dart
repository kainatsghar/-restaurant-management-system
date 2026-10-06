import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class RouteInfo {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final bool isRealRoad;

  RouteInfo({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.isRealRoad = true,
  });
}

class RouteService {
  static final Map<String, RouteInfo> _cache = {};
  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 7);

  /// Fetch real turn-by-turn road route between [start] and [destination] using OSRM
  static Future<RouteInfo> fetchRoadRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    // Generate cache key rounded to 4 decimals (~11m precision)
    final cacheKey =
        '${start.latitude.toStringAsFixed(4)},${start.longitude.toStringAsFixed(4)}->${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // OSRM requires {longitude},{latitude};{longitude},{latitude}
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );

      final request = await _httpClient.getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, 'RestaurantManagementApp/1.0');
      final response = await request.close().timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;

        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0] as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List<dynamic>?;

          if (coordinates != null && coordinates.isNotEmpty) {
            final List<LatLng> points = [];
            for (final coord in coordinates) {
              if (coord is List && coord.length >= 2) {
                final double lng = (coord[0] as num).toDouble();
                final double lat = (coord[1] as num).toDouble();
                points.add(LatLng(lat, lng));
              }
            }

            final double distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
            final double durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0.0;

            final distanceKm = distanceMeters / 1000.0;
            final durationMinutes = math.max(1, (durationSeconds / 60.0).round());

            final routeInfo = RouteInfo(
              points: points,
              distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
              durationMinutes: durationMinutes,
              isRealRoad: true,
            );

            _cache[cacheKey] = routeInfo;
            return routeInfo;
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM Route fetch error (falling back to realistic street interpolation): $e');
    }

    // Fallback: Generate realistic street-like turns and intermediate waypoints
    final fallbackInfo = _generateRealisticStreetRoute(start, destination);
    return fallbackInfo;
  }

  /// In case of offline/timeout, generates realistic road-like turns instead of a direct 1-line chord
  static RouteInfo _generateRealisticStreetRoute(LatLng start, LatLng destination) {
    final List<LatLng> points = [start];

    final latDiff = destination.latitude - start.latitude;
    final lngDiff = destination.longitude - start.longitude;

    // Create 4-6 realistic city block turns
    const int steps = 5;
    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      // Stagger along streets (Manhattan / Grid-like turns)
      final midLat = i.isEven
          ? start.latitude + latDiff * t
          : start.latitude + latDiff * (t - 0.08);
      final midLng = i.isEven
          ? start.longitude + lngDiff * (t - 0.05)
          : start.longitude + lngDiff * t;
      points.add(LatLng(midLat, midLng));
    }

    points.add(destination);

    // Approximate distance in km using Haversine
    const Distance distanceCalc = Distance();
    final double distMeters = distanceCalc.as(LengthUnit.Meter, start, destination);
    final double distKm = (distMeters * 1.3) / 1000.0; // 1.3x road detour factor
    final int mins = math.max(2, (distKm * 3.5).round()); // ~20 km/h city average

    return RouteInfo(
      points: points,
      distanceKm: double.parse(distKm.toStringAsFixed(2)),
      durationMinutes: mins,
      isRealRoad: false,
    );
  }
}
