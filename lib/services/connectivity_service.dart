import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Connectivity Service — monitors real network reachability with debounce.
///
/// Uses `connectivity_plus` for instant network-change events, then
/// performs an actual HTTP ping to confirm true internet access.
/// Debounces state transitions by 3 seconds to prevent flapping in
/// areas with unstable coverage (ghats, tunnels, mountain passes).
class ConnectivityService {
  // Singleton
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;
  Timer? _debounceTimer;

  /// Debounce duration — state must be stable for this long before we publish.
  static const _debounceDuration = Duration(seconds: 3);

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Initialize and start monitoring connectivity.
  Future<void> initialize() async {
    // Check current state immediately (no debounce for initial check)
    await _checkConnectivity(debounce: false);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      // connectivity_plus v6 returns List<ConnectivityResult>
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      
      if (!hasNetwork) {
        // Definitely offline — no network interface at all
        _scheduleStatusUpdate(false);
      } else {
        // Has a network interface, but verify actual internet access
        await _checkConnectivity(debounce: true);
      }
    });
  }

  /// Perform a lightweight HTTP reachability check.
  Future<void> _checkConnectivity({bool debounce = true}) async {
    bool reachable = false;
    try {
      final response = await http.get(
        Uri.parse('https://connectivitycheck.gstatic.com/generate_204'),
      ).timeout(const Duration(seconds: 5));

      reachable = (response.statusCode == 204 || response.statusCode == 200);
    } catch (e) {
      debugPrint('[Connectivity] Reachability check failed: $e');
      reachable = false;
    }

    if (debounce) {
      _scheduleStatusUpdate(reachable);
    } else {
      _updateStatus(reachable);
    }
  }

  /// Debounce state change — only publish after [_debounceDuration] of stable state.
  /// This prevents banner flicker, repeated TTS spam, and reroute triggers
  /// in areas with unstable cell coverage.
  void _scheduleStatusUpdate(bool online) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _updateStatus(online);
    });
  }

  void _updateStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _controller.add(online);
      debugPrint('[Connectivity] Status changed: ${online ? "ONLINE" : "OFFLINE"}');
    }
  }

  /// Force a connectivity re-check (useful after recovering from a tunnel).
  /// Bypasses debounce for immediate feedback.
  Future<bool> forceCheck() async {
    await _checkConnectivity(debounce: false);
    return _isOnline;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    _controller.close();
  }
}
