import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme.dart';
import '../providers/navigation_provider.dart';
import '../services/ola_tile_proxy.dart';
import 'member_marker.dart';
import 'navigation_marker.dart';

/// Reusable Map Widget wrapping flutter_map.
///
/// Can display the route polyline, member markers, and nearby POIs.
/// Uses AnimatedMarkerLayer for smooth marker transitions.
class TrailMapWidget extends StatefulWidget {
  final MapController mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final List<LatLng> routePolyline;
  final Map<String, MemberPosition> memberPositions;
  final String? currentUserId;
  final String? leaderId;
  final bool isDrivingMode;
  final double? initialRouteBearing;
  final double deviceHeading;

  const TrailMapWidget({
    super.key,
    required this.mapController,
    this.initialCenter = const LatLng(0, 0),
    this.initialZoom = 14.0,
    this.routePolyline = const [],
    this.memberPositions = const {},
    this.currentUserId,
    this.leaderId,
    this.isDrivingMode = false,
    this.initialRouteBearing,
    this.deviceHeading = 0.0,
  });

  @override
  State<TrailMapWidget> createState() => _TrailMapWidgetState();
}

class _TrailMapWidgetState extends State<TrailMapWidget> with TickerProviderStateMixin {

  // Track previous positions for smooth animation
  final Map<String, LatLng> _previousPositions = {};
  final Map<String, LatLng> _animatedPositions = {};
  final Map<String, AnimationController> _positionAnimControllers = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TrailMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate markers when their positions change
    for (final entry in widget.memberPositions.entries) {
      final userId = entry.key;
      final newPos = entry.value.latLng;
      final prevPos = _previousPositions[userId];

      if (prevPos != null && (prevPos.latitude != newPos.latitude || prevPos.longitude != newPos.longitude)) {
        _animateMarker(userId, prevPos, newPos);
      } else {
        _animatedPositions[userId] = newPos;
      }
      _previousPositions[userId] = newPos;
    }
  }

  void _animateMarker(String userId, LatLng from, LatLng to) {
    _positionAnimControllers[userId]?.dispose();

    final controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    final latTween = Tween<double>(begin: from.latitude, end: to.latitude);
    final lngTween = Tween<double>(begin: from.longitude, end: to.longitude);
    final curved = CurvedAnimation(parent: controller, curve: Curves.easeInOut);

    controller.addListener(() {
      setState(() {
        _animatedPositions[userId] = LatLng(
          latTween.evaluate(curved),
          lngTween.evaluate(curved),
        );
      });
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animatedPositions[userId] = to;
      }
    });

    _positionAnimControllers[userId] = controller;
    controller.forward();
  }

  @override
  void dispose() {
    for (final c in _positionAnimControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        maxZoom: 18.0,
        minZoom: 3.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Raster Map Tiles Layer (Colorful with labels)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.trialmate',
        ),

        // Route Polyline
            if (widget.routePolyline.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePolyline,
                    color: AppTheme.accentBlue.withValues(alpha: 0.8),
                    strokeWidth: 6.0,
                    borderStrokeWidth: 2.0,
                    borderColor: AppTheme.primaryDark,
                  ),
                ],
              ),

            // Member Markers (with smooth animation)
            MarkerLayer(
              markers: [
                if (widget.routePolyline.isNotEmpty)
                  Marker(
                    point: widget.routePolyline.first,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: AppTheme.accentGreen, size: 40),
                  ),
                if (widget.routePolyline.isNotEmpty && widget.routePolyline.length > 1)
                  Marker(
                    point: widget.routePolyline.last,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.flag_rounded, color: AppTheme.accentRed, size: 40),
                  ),
                ...widget.memberPositions.values.map((pos) {
                  final isMe = pos.userId == widget.currentUserId;
                  final isLeader = pos.userId == widget.leaderId;
                  
                  // Use the animated position if available, otherwise raw
                  final displayPos = _animatedPositions[pos.userId] ?? pos.latLng;

                  if (isMe && widget.isDrivingMode) {
                    return Marker(
                      point: displayPos,
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      rotate: true,
                      child: GoogleNavigationMarker(
                        heading: pos.speed < 1.0 ? widget.deviceHeading : pos.heading,
                      ),
                    );
                  }

                  return Marker(
                    point: displayPos,
                    width: 80,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: MemberMarker(
                      name: pos.name,
                      isLeader: isLeader,
                      status: pos.status,
                    ),
                  );
                }),
              ],
            ),
          ],
    );
  }
}
