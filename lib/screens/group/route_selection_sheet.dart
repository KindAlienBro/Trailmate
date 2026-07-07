import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme.dart';
import '../../utils/polyline_decoder.dart'; // for decodePolyline

class RouteSelectionSheet extends StatefulWidget {
  final List<dynamic> routes;
  final LatLng origin;
  final LatLng destination;
  final Function(dynamic) onRouteSelected;

  const RouteSelectionSheet({
    super.key,
    required this.routes,
    required this.origin,
    required this.destination,
    required this.onRouteSelected,
  });

  @override
  State<RouteSelectionSheet> createState() => _RouteSelectionSheetState();
}

class _RouteSelectionSheetState extends State<RouteSelectionSheet> {
  int _selectedIndex = 0;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitBounds();
    });
  }

  void _fitBounds() {
    final bounds = LatLngBounds.fromPoints([
      widget.origin,
      widget.destination,
      // Add a few points from the first route to ensure good bounds
      if (widget.routes.isNotEmpty)
        ...decodePolyline(widget.routes[0]['overview_polyline'] ?? ''),
    ]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Select a Route',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          
          // Map Preview
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.origin,
                    initialZoom: 12.0,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.trialmate',
                    ),
                    PolylineLayer(
                      polylines: [
                        // Draw unselected routes first
                        for (int i = 0; i < widget.routes.length; i++)
                          if (i != _selectedIndex)
                            Polyline(
                              points: decodePolyline(widget.routes[i]['overview_polyline'] ?? ''),
                              color: Colors.grey.withValues(alpha: 0.8),
                              strokeWidth: 4.0,
                            ),
                        // Draw selected route on top
                        if (widget.routes.isNotEmpty)
                          Polyline(
                            points: decodePolyline(widget.routes[_selectedIndex]['overview_polyline'] ?? ''),
                            color: AppTheme.accentBlue,
                            strokeWidth: 6.0,
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: widget.origin,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: AppTheme.accentGreen, size: 40),
                        ),
                        Marker(
                          point: widget.destination,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: AppTheme.accentRed, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Route List
          Expanded(
            flex: 2,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.routes.length,
              itemBuilder: (context, index) {
                final route = widget.routes[index];
                final legs = route['legs'] as List?;
                final distance = legs?.isNotEmpty == true ? legs![0]['distance'] : 0;
                final duration = legs?.isNotEmpty == true ? legs![0]['duration'] : 0;
                
                final distStr = (distance / 1000).toStringAsFixed(1);
                final durMins = (duration / 60).round();
                final durStr = durMins > 60 
                    ? '${(durMins / 60).floor()}h ${durMins % 60}m' 
                    : '${durMins}m';

                final isSelected = index == _selectedIndex;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accentBlue.withValues(alpha: 0.15) : AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.accentBlue : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_car_rounded,
                          color: isSelected ? AppTheme.accentBlue : AppTheme.textSecondary,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Route ${index + 1}',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'via Primary Roads',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              durStr,
                              style: TextStyle(
                                color: isSelected ? AppTheme.accentBlue : AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$distStr km',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Confirm Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  widget.onRouteSelected(widget.routes[_selectedIndex]);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Select Route',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16), // Bottom safe area
        ],
      ),
    );
  }
}
