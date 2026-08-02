import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

/// Ola Maps Service
///
/// Calls the backend proxy endpoints for all Ola Maps API features:
/// Directions, Nearby Search, Autocomplete, Geocoding, Distance Matrix, Snap to Road.
class OlaMapsService {
  final String _baseUrl = AppConstants.serverBaseUrl;
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ==================== API Usage ====================

  /// Get the API token usage for the current user
  Future<Map<String, dynamic>> getApiUsage() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl${AppConstants.apiUsageEndpoint}'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to load API usage: ${response.body}');
    } catch (e) {
      throw Exception('Failed to get API usage: $e');
    }
  }

  // ==================== Directions ====================

  /// Get route directions from origin to destination with optional waypoints.
  /// Returns route with polyline, distance, and duration.
  Future<Map<String, dynamic>> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<Map<String, double>>? waypoints,
    String? mode,
    bool alternatives = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'origin': '$originLat,$originLng',
        'destination': '$destLat,$destLng',
      };

      if (mode != null) {
        body['mode'] = mode;
      }
      if (alternatives) {
        body['alternatives'] = true;
      }

      if (waypoints != null && waypoints.isNotEmpty) {
        body['waypoints'] = waypoints
            .map((w) => '${w['lat']},${w['lng']}')
            .join('|');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl${AppConstants.directionsEndpoint}'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Directions API error: ${response.body}');
    } catch (e) {
      throw Exception('Failed to get directions: $e');
    }
  }

  // ==================== Smart Route (AI-Powered) ====================

  /// Get an AI-optimized route with adventure waypoints.
  /// Mode: 'highway' (direct), 'adventure' (scenic), 'full_adventure' (off-beat)
  Future<Map<String, dynamic>> getSmartRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'highway',
    String? transportMode,
    List<Map<String, dynamic>>? waypoints,
  }) async {
    try {
      final body = <String, dynamic>{
        'origin': '$originLat,$originLng',
        'destination': '$destLat,$destLng',
        'mode': mode,
      };

      if (transportMode != null) {
        body['transportMode'] = transportMode;
      }
      if (waypoints != null) {
        body['waypoints'] = waypoints;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl${AppConstants.smartRouteEndpoint}'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Smart route API error: ${response.body}');
    } catch (e) {
      throw Exception('Failed to get smart route: $e');
    }
  }

  /// Suggest waypoints for the given route without generating the final polyline.
  Future<Map<String, dynamic>> suggestWaypoints({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'highway',
    String? transportMode,
  }) async {
    try {
      final body = <String, dynamic>{
        'origin': '$originLat,$originLng',
        'destination': '$destLat,$destLng',
        'mode': mode,
      };

      if (transportMode != null) {
        body['transportMode'] = transportMode;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl${AppConstants.suggestWaypointsEndpoint}'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Suggest waypoints API error: ${response.body}');
    } catch (e) {
      throw Exception('Failed to suggest waypoints: $e');
    }
  }

  // ==================== Nearby Search ====================

  /// Search for nearby places by category.
  /// Types: gas_station, restaurant, hospital, lodging, parking
  Future<Map<String, dynamic>> nearbySearch({
    required double lat,
    required double lng,
    required String type,
    int? radius,
  }) async {
    try {
      final params = {
        'location': '$lat,$lng',
        'types': type,
        if (radius != null) 'radius': '$radius',
      };

      final uri = Uri.parse('$_baseUrl${AppConstants.nearbyEndpoint}')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Nearby search error: ${response.body}');
    } catch (e) {
      throw Exception('Failed to search nearby: $e');
    }
  }

  // ==================== Autocomplete ====================

  /// Get place autocomplete suggestions for a search query.
  Future<Map<String, dynamic>> autocomplete({
    required String input,
    double? lat,
    double? lng,
  }) async {
    try {
      final params = <String, String>{
        'input': input,
        if (lat != null && lng != null) 'location': '$lat,$lng',
      };

      final uri = Uri.parse('$_baseUrl${AppConstants.autocompleteEndpoint}')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Autocomplete error: ${response.body}');
    } catch (e) {
      throw Exception('Failed to autocomplete: $e');
    }
  }

  // ==================== Geocoding ====================

  /// Convert address to coordinates
  Future<Map<String, dynamic>> geocode(String address) async {
    try {
      final uri = Uri.parse('$_baseUrl${AppConstants.geocodeEndpoint}')
          .replace(queryParameters: {'address': address});

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Geocode error: ${response.body}');
    } catch (e) {
      throw Exception('Failed to geocode: $e');
    }
  }

  /// Convert coordinates to address
  Future<Map<String, dynamic>> reverseGeocode({required double lat, required double lng}) async {
    try {
      final uri = Uri.parse('$_baseUrl${AppConstants.reverseGeocodeEndpoint}')
          .replace(queryParameters: {'latlng': '$lat,$lng'});

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Reverse geocode error: ${response.body}');
    } catch (e) {
      throw Exception('Failed to reverse geocode: $e');
    }
  }

  // ==================== Distance Matrix ====================

  /// Calculate distances between multiple origins and destinations.
  Future<Map<String, dynamic>> distanceMatrix({
    required List<Map<String, double>> origins,
    required List<Map<String, double>> destinations,
  }) async {
    try {
      final body = {
        'origins': origins.map((o) => '${o['lat']},${o['lng']}').join('|'),
        'destinations':
            destinations.map((d) => '${d['lat']},${d['lng']}').join('|'),
      };

      final response = await http.post(
        Uri.parse('$_baseUrl${AppConstants.distanceMatrixEndpoint}'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Distance matrix error: ${response.body}');
    } catch (e) {
      throw Exception('Failed to get distance matrix: $e');
    }
  }

  // ==================== Snap to Road ====================

  /// Snap GPS coordinates to the nearest road.
  Future<Map<String, dynamic>> snapToRoad(
      List<Map<String, double>> points) async {
    try {
      final body = {
        'points': points.map((p) => '${p['lat']},${p['lng']}').join('|'),
      };

      final response = await http.post(
        Uri.parse('$_baseUrl${AppConstants.snapToRoadEndpoint}'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Snap to road error: ${response.body}');
    } catch (e) {
      throw Exception('Failed to snap to road: $e');
    }
  }
}
