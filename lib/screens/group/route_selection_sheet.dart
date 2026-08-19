import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/group_provider.dart';
import '../../core/app_colors.dart';
import '../../utils/polyline_decoder.dart'; // for decodePolyline

class RouteSelectionSheet extends StatefulWidget {
  final List<dynamic> routes;
  final LatLng origin;
  final LatLng destination;
  final List<AIWaypoint>? aiWaypoints;
  final String? routeCharacter;
  final Function(dynamic) onRouteSelected;

  RouteSelectionSheet({
    super.key,
    required this.routes,
    required this.origin,
    required this.destination,
    this.aiWaypoints,
    this.routeCharacter,
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
        ...decodePolyline(widget.routes[0]['overview_polyline'] ?? widget.routes[0]['geometry'] ?? ''),
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
    final colors = AppColors.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colors.surfaceColor,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              widget.routes.length == 1 ? 'Route Preview' : 'Select a Route',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
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
                    interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.vorniity.rouniity',
                    ),
                    PolylineLayer(
                      polylines: [
                        // Draw unselected routes first
                        for (int i = 0; i < widget.routes.length; i++)
                          if (i != _selectedIndex)
                            Polyline(
                              points: decodePolyline(widget.routes[i]['overview_polyline'] ?? widget.routes[i]['geometry'] ?? ''),
                              color: Colors.grey.withValues(alpha: 0.8),
                              strokeWidth: 4.0,
                            ),
                        // Draw selected route on top
                        if (widget.routes.isNotEmpty)
                          Polyline(
                            points: decodePolyline(widget.routes[_selectedIndex]['overview_polyline'] ?? widget.routes[_selectedIndex]['geometry'] ?? ''),
                            color: colors.accentPrimary,
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
                          child: Icon(Icons.location_on, color: colors.accentSecondary, size: 40),
                        ),
                        Marker(
                          point: widget.destination,
                          width: 40,
                          height: 40,
                          child: Icon(Icons.location_on, color: colors.accentDanger, size: 40),
                        ),
                        // AI waypoint markers
                        if (widget.aiWaypoints != null)
                          ...widget.aiWaypoints!.map((wp) => Marker(
                            point: LatLng(wp.lat, wp.lng),
                            width: 36,
                            height: 36,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colors.accentExtra,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(color: colors.accentExtra.withValues(alpha: 0.4), blurRadius: 6)],
                              ),
                              child: Center(
                                child: Text(wp.emoji, style: TextStyle(fontSize: 14)),
                              ),
                            ),
                          )),
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
                      color: isSelected ? colors.accentPrimary.withValues(alpha: 0.15) : colors.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? colors.accentPrimary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.directions_car_rounded,
                              color: isSelected ? colors.accentPrimary : colors.textSecondary,
                              size: 28,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Route ${index + 1}',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'via ${route['summary'] ?? (legs?.isNotEmpty == true ? legs![0]['summary'] : null) ?? 'Primary Roads'}',
                                    style: TextStyle(
                                      color: colors.textSecondary,
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
                                    color: isSelected ? colors.accentPrimary : colors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '$distStr km',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // AI waypoint chips
                        if (widget.aiWaypoints != null && widget.aiWaypoints!.isNotEmpty && isSelected) ...[
                          SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: widget.aiWaypoints!.map((wp) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colors.accentExtra.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colors.accentExtra.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '${wp.emoji} ${wp.name}',
                                style: TextStyle(fontSize: 11, color: colors.accentExtra, fontWeight: FontWeight.w500),
                              ),
                            )).toList(),
                          ),
                        ],
                        // Route character description
                        if (widget.routeCharacter != null && widget.routeCharacter!.isNotEmpty && isSelected) ...[
                          SizedBox(height: 8),
                          Text(
                            widget.routeCharacter!,
                            style: TextStyle(fontSize: 11, color: colors.textTertiary, fontStyle: FontStyle.italic),
                          ),
                        ],
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
                  backgroundColor: colors.accentPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  widget.routes.length == 1 ? 'Confirm & Create Trip' : 'Select Route',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ),
          SizedBox(height: 16), // Bottom safe area
        ],
      ),
    );
  }
}
