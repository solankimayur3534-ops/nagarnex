import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'constants.dart';
import 'geo_utils.dart';

class ResolvedCityLocation {
  final String city;
  final String locality;
  final String wardLabel;

  const ResolvedCityLocation({
    required this.city,
    required this.locality,
    required this.wardLabel,
  });
}

class CityLocator {
  static const List<({String city, double lat, double lng})> _majorCities = [
    (city: 'Bengaluru', lat: 12.9716, lng: 77.5946),
    (city: 'Rajkot', lat: 22.3039, lng: 70.8022),
    (city: 'Hyderabad', lat: 17.3850, lng: 78.4867),
    (city: 'Ahmedabad', lat: 23.0225, lng: 72.5714),
    (city: 'Surat', lat: 21.1702, lng: 72.8311),
    (city: 'Vadodara', lat: 22.3072, lng: 73.1812),
    (city: 'Mumbai', lat: 19.0760, lng: 72.8777),
    (city: 'Pune', lat: 18.5204, lng: 73.8567),
    (city: 'Delhi', lat: 28.6139, lng: 77.2090),
    (city: 'Chennai', lat: 13.0827, lng: 80.2707),
    (city: 'Kolkata', lat: 22.5726, lng: 88.3639),
    (city: 'Jaipur', lat: 26.9124, lng: 75.7873),
  ];

  /// Resolves [point] to a city, locality, and ward label using Bengaluru
  /// presets first, then Nominatim reverse geocoding, with offline fallback.
  static Future<ResolvedCityLocation> resolveLocationDetails(
      LatLng point) async {
    // 1. Check if within 30 km of Bengaluru center
    final blrDist =
        GeoUtils.distanceMeters(point, AppConstants.bengaluruCenter);
    if (blrDist <= 30000) {
      int nearestIdx = 0;
      double minDist = double.infinity;
      for (int i = 0; i < AppConstants.bengaluruPresets.length; i++) {
        final p = AppConstants.bengaluruPresets[i];
        final d = GeoUtils.distanceMeters(
          point,
          LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
        );
        if (d < minDist) {
          minDist = d;
          nearestIdx = i;
        }
      }
      final preset = AppConstants.bengaluruPresets[nearestIdx];
      return ResolvedCityLocation(
        city: 'Bengaluru',
        locality: preset['place'].toString(),
        wardLabel: preset['ward'].toString(),
      );
    }

    // 2. Try free OpenStreetMap Nominatim reverse geocoding
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2'
        '&lat=${point.latitude}&lon=${point.longitude}&zoom=14',
      );
      final resp = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = (data['address'] as Map<String, dynamic>?) ?? {};
        final city = (addr['city'] ??
                addr['town'] ??
                addr['state_district'] ??
                addr['county'] ??
                addr['state'] ??
                '')
            .toString()
            .trim();
        final locality = (addr['suburb'] ??
                addr['neighbourhood'] ??
                addr['road'] ??
                addr['village'] ??
                city)
            .toString()
            .trim();
        if (city.isNotEmpty) {
          final cleanCity = city.replaceAll(' District', '').trim();
          final cleanLocality = locality.isEmpty ? cleanCity : locality;
          return ResolvedCityLocation(
            city: cleanCity,
            locality: cleanLocality,
            wardLabel: cleanLocality == cleanCity
                ? '$cleanCity Central'
                : '$cleanCity · $cleanLocality',
          );
        }
      }
    } catch (_) {}

    // 3. Offline / fallback major Indian cities check (< 60 km)
    String fallbackCity = 'Local City';
    double bestDist = double.infinity;
    for (final c in _majorCities) {
      final d = GeoUtils.distanceMeters(point, LatLng(c.lat, c.lng));
      if (d < bestDist) {
        bestDist = d;
        fallbackCity = c.city;
      }
    }
    if (bestDist > 80000) {
      fallbackCity = 'Custom Location';
    }
    return ResolvedCityLocation(
      city: fallbackCity,
      locality: '$fallbackCity Area',
      wardLabel: '$fallbackCity Ward',
    );
  }
}
