import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'place_image_service.dart';

class TouristPlace {
  final String name;
  final double lat;
  final double lon;
  final String type;
  final double distanceKm;
  final String imageUrl;

  TouristPlace({
    required this.name,
    required this.lat,
    required this.lon,
    required this.type,
    required this.distanceKm,
    required this.imageUrl,
  });
}

class ExploreService {
  /// Fetches nearby tourist places using Ola Maps backend proxy.
  /// Each place's image is fetched dynamically from Wikipedia — no placeholders.
  static Future<List<TouristPlace>> fetchNearbyPlaces({
    double? lat,
    double? lon,
    double radiusInKm = 50.0,
    String? token,
  }) async {
    double currentLat = lat ?? 12.9716;
    double currentLon = lon ?? 77.5946;

    if (lat == null || lon == null) {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 5),
              ),
            );
            currentLat = pos.latitude;
            currentLon = pos.longitude;
          }
        }
      } catch (e) {
        debugPrint('Failed to get location for explore: $e');
      }
    }

    // Skip API call if there's no auth token — go straight to fallback places
    if (token == null) {
      debugPrint('ExploreService: no token, using fallback places');
      return _getFallbackPlaces();
    }

    try {
      // Types: park, tourist_attraction, museum
      final types = 'tourist_attraction,museum,park';
      final radiusMeters = (radiusInKm * 1000).toInt();
      final url =
          '${AppConstants.serverBaseUrl}${AppConstants.nearbyEndpoint}'
          '?location=$currentLat,$currentLon&types=$types&radius=$radiusMeters';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predictions = data['predictions'] as List<dynamic>? ?? [];

        if (predictions.isEmpty) return _getFallbackPlaces();

        final List<TouristPlace> places = [];
        for (var p in predictions) {
          final name = p['name'] ?? p['description'] ?? 'Unknown Place';
          final geometry = p['geometry']?['location'];
          if (geometry == null) continue;

          final pLat = geometry['lat']?.toDouble() ?? 0.0;
          final pLon = geometry['lng']?.toDouble() ?? 0.0;
          final dist =
              Geolocator.distanceBetween(currentLat, currentLon, pLat, pLon) /
                  1000.0;

          // Dynamically fetch the real photo for this exact place
          final imageUrl = await PlaceImageService.fetchImageUrl(
            name,
            lat: pLat,
            lon: pLon,
          );

          places.add(TouristPlace(
            name: name,
            lat: pLat,
            lon: pLon,
            type: 'attraction',
            distanceKm: double.parse(dist.toStringAsFixed(1)),
            imageUrl: imageUrl,
          ));
        }

        places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        return places;
      } else {
        debugPrint('Explore API failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Explore API error: $e');
    }

    return _getFallbackPlaces();
  }

  /// Returns fallback places with dynamically fetched real images — all in parallel.
  static Future<List<TouristPlace>> _getFallbackPlaces() async {
    final rawPlaces = [
      {'name': 'Nandi Hills',      'lat': 13.3702, 'lon': 77.6835, 'type': 'peak',      'dist': 60.0},
      {'name': 'Mysore Palace',    'lat': 12.3051, 'lon': 76.6551, 'type': 'monument',  'dist': 145.0},
      {'name': 'Coorg Madikeri',   'lat': 12.4244, 'lon': 75.7382, 'type': 'viewpoint', 'dist': 265.0},
      {'name': 'Ooty',             'lat': 11.4102, 'lon': 76.6950, 'type': 'peak',      'dist': 270.0},
      {'name': 'Gokarna Beach',    'lat': 14.5500, 'lon': 74.3180, 'type': 'beach',     'dist': 480.0},
      {'name': 'Hampi',            'lat': 15.3350, 'lon': 76.4600, 'type': 'ruins',     'dist': 340.0},
    ];

    // Fetch all images in parallel — not sequentially
    final imageUrls = await Future.wait(
      rawPlaces.map((p) => PlaceImageService.fetchImageUrl(
        p['name'] as String,
        lat: p['lat'] as double,
        lon: p['lon'] as double,
      )),
    );

    return List.generate(rawPlaces.length, (i) {
      final p = rawPlaces[i];
      return TouristPlace(
        name: p['name'] as String,
        lat: p['lat'] as double,
        lon: p['lon'] as double,
        type: p['type'] as String,
        distanceKm: p['dist'] as double,
        imageUrl: imageUrls[i],
      );
    });
  }
}
