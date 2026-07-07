/// TrailMate App Constants
///
/// Centralized configuration for the entire app — API endpoints,
/// alert thresholds, POI categories, and map settings.

class AppConstants {
  // ==================== Server ====================
  /// Backend server base URL
  static const String serverBaseUrl = 'http://10.40.39.73:3000'; // Wi-Fi IP
  static const String serverWsUrl = 'http://10.40.39.73:3000';   // Socket.IO URL

  // For physical device on same WiFi, use your machine's local IP:
  // static const String serverBaseUrl = 'http://192.168.x.x:3000';

  // ==================== API Endpoints ====================
  static const String apiPrefix = '/api';

  // Auth
  static const String loginEndpoint = '$apiPrefix/auth/login';
  static const String registerEndpoint = '$apiPrefix/auth/register';
  static const String profileEndpoint = '$apiPrefix/auth/me';

  // Groups
  static const String groupsEndpoint = '$apiPrefix/groups';
  static const String joinGroupEndpoint = '$apiPrefix/groups/join';
  static const String myGroupsEndpoint = '$apiPrefix/groups/my';

  // Ola Maps Proxy
  static const String directionsEndpoint = '$apiPrefix/maps/directions';
  static const String nearbyEndpoint = '$apiPrefix/maps/nearby';
  static const String autocompleteEndpoint = '$apiPrefix/maps/autocomplete';
  static const String geocodeEndpoint = '$apiPrefix/maps/geocode';
  static const String reverseGeocodeEndpoint = '$apiPrefix/maps/reverse-geocode';
  static const String distanceMatrixEndpoint = '$apiPrefix/maps/distance-matrix';
  static const String snapToRoadEndpoint = '$apiPrefix/maps/snap-to-road';
  static const String apiUsageEndpoint = '$apiPrefix/maps/usage';

  // ==================== Map Tiles ====================
  static const String olaVectorStyleUrl =
      'https://api.olamaps.io/tiles/vector/v1/styles/default-light-standard/style.json?api_key={key}';
  
  static const String olaApiKey = 'Txtd52X2o49O1UlPk7euny0DUhjd65VGQaMWzBoR';

  // ==================== Alert Thresholds ====================
  /// Distance from route polyline (meters) before deviation alert fires
  static const double deviationThresholdMeters = 500;

  /// Distance behind leader (meters) before separation alert fires
  static const double separationThresholdMeters = 2000;

  /// Minutes without movement before stall alert fires
  static const int stallTimeoutMinutes = 10;

  /// Location update interval in seconds (how often GPS is sent to server)
  static const int locationUpdateIntervalSeconds = 5;

  // ==================== Group Settings ====================
  /// Maximum members in a group
  static const int maxGroupMembers = 20;

  /// Invite code length
  static const int inviteCodeLength = 6;

  // ==================== POI Categories ====================
  /// Mapping of POI categories to their Ola Maps API type string
  static const Map<String, String> poiCategories = {
    'Fuel': 'gas_station',
    'Food': 'restaurant',
    'Hospital': 'hospital',
    'Hotel': 'lodging',
    'Parking': 'parking',
  };

  /// Icons for each POI category
  static const Map<String, String> poiIcons = {
    'Fuel': '⛽',
    'Food': '🍽️',
    'Hospital': '🏥',
    'Hotel': '🏨',
    'Parking': '🅿️',
  };

  // ==================== Secure Storage Keys ====================
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String userEmailKey = 'user_email';
}
