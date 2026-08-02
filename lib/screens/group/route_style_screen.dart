import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../services/ola_maps_service.dart';
import '../../utils/polyline_decoder.dart';

class RouteStyleScreen extends StatefulWidget {
  final String tripName;
  final String transportMode;
  final PlaceModel origin;
  final PlaceModel destination;

  const RouteStyleScreen({
    super.key,
    required this.tripName,
    required this.transportMode,
    required this.origin,
    required this.destination,
  });

  @override
  State<RouteStyleScreen> createState() => _RouteStyleScreenState();
}

class _RouteStyleScreenState extends State<RouteStyleScreen> {
  final OlaMapsService _mapsService = OlaMapsService();
  final MapController _mapController = MapController();
  
  late PageController _carouselController;
  int _currentCarouselIndex = 0;
  
  String _selectedRouteMode = 'highway';
  
  int _currentStep = 0; // 0: Style, 1: Spot Selection, 2: Preview
  bool _isPreviewLoading = false;
  List<AIWaypoint>? _suggestedWaypoints;
  List<AIWaypoint> _selectedWaypoints = [];
  
  List<dynamic>? _previewRoutes;
  int _selectedRouteIndex = 0;
  List<AIWaypoint>? _previewAiWaypoints;
  String? _previewRouteCharacter;
  bool _isCreating = false;

  final List<Map<String, dynamic>> _routeModes = [
    {
      'id': 'highway',
      'icon': Icons.speed_rounded,
      'title': 'Highway',
      'subtitle': 'Fastest route. No detours.',
      'gradient': const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF1565C0)]),
    },
    {
      'id': 'adventure',
      'icon': Icons.terrain_rounded,
      'title': 'Adventure',
      'subtitle': 'Scenic detours, ghats & hill routes.',
      'gradient': const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF2E7D32)]),
    },
    {
      'id': 'full_adventure',
      'icon': Icons.explore_rounded,
      'title': 'Full Adventure',
      'subtitle': 'Jungle trails, water crossings.',
      'gradient': const LinearGradient(colors: [Color(0xFFF4511E), Color(0xFFE65100)]),
    },
    {
      'id': 'cultural',
      'icon': Icons.account_balance_rounded,
      'title': 'Cultural',
      'subtitle': 'Museums, ancient temples.',
      'gradient': const LinearGradient(colors: [Color(0xFF8E24AA), Color(0xFF6A1B9A)]),
    },
    {
      'id': 'foodie',
      'icon': Icons.restaurant_rounded,
      'title': 'Foodie',
      'subtitle': 'Famous eateries, cafes.',
      'gradient': const LinearGradient(colors: [Color(0xFFF4511E), Color(0xFFD84315)]),
    },
    {
      'id': 'coastal',
      'icon': Icons.beach_access_rounded,
      'title': 'Coastal',
      'subtitle': 'Beaches, scenic coastlines.',
      'gradient': const LinearGradient(colors: [Color(0xFF00ACC1), Color(0xFF00838F)]),
    },
    {
      'id': 'wildlife',
      'icon': Icons.pets_rounded,
      'title': 'Wildlife',
      'subtitle': 'National parks, reserves.',
      'gradient': const LinearGradient(colors: [Color(0xFF7CB342), Color(0xFF558B2F)]),
    },
  ];

  @override
  void initState() {
    super.initState();
    _carouselController = PageController(viewportFraction: 0.65);
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestedSpots() async {
    setState(() => _isPreviewLoading = true);
    if(mounted) _mapsService.setToken(context.read<AuthProvider>().token ?? '');

    try {
      if (_selectedRouteMode == 'highway') {
        await _fetchFinalRoute([]);
        return;
      }

      final dir = await _mapsService.suggestWaypoints(
        originLat: widget.origin.lat!,
        originLng: widget.origin.lng!,
        destLat: widget.destination.lat!,
        destLng: widget.destination.lng!,
        mode: _selectedRouteMode,
        transportMode: widget.transportMode,
      );

      final aiWaypointsJson = dir['aiWaypoints'] as List? ?? [];
      final spots = aiWaypointsJson.map((w) => AIWaypoint.fromJson(Map<String, dynamic>.from(w))).toList();

      setState(() {
        _suggestedWaypoints = spots;
        _selectedWaypoints = [];
        _previewRouteCharacter = dir['routeCharacter'] as String?;
        _currentStep = 1;
        _isPreviewLoading = false;
      });
      _fitMapBoundsForSpots();
    } catch (e) {
      setState(() => _isPreviewLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load spots: $e')));
      }
    }
  }

  Future<void> _fetchFinalRoute(List<AIWaypoint> waypoints) async {
    setState(() => _isPreviewLoading = true);
    try {
      final Map<String, dynamic> dir;
      if (_selectedRouteMode != 'highway' && waypoints.isNotEmpty) {
        dir = await _mapsService.getSmartRoute(
          originLat: widget.origin.lat!,
          originLng: widget.origin.lng!,
          destLat: widget.destination.lat!,
          destLng: widget.destination.lng!,
          mode: _selectedRouteMode,
          transportMode: widget.transportMode,
          waypoints: waypoints.map((w) => w.toJson()).toList(),
        );
      } else {
        dir = await _mapsService.getDirections(
          originLat: widget.origin.lat!,
          originLng: widget.origin.lng!,
          destLat: widget.destination.lat!,
          destLng: widget.destination.lng!,
          mode: widget.transportMode,
          alternatives: true,
        );
      }

      if (dir['routes'] != null && (dir['routes'] as List).isNotEmpty) {
        setState(() {
          _previewRoutes = dir['routes'];
          _previewAiWaypoints = waypoints;
          _selectedRouteIndex = 0;
          _currentStep = 2;
          _isPreviewLoading = false;
          _previewRouteCharacter = dir['routeCharacter'] as String?;
        });
        _fitMapBounds();
      } else {
        throw Exception('No routes found');
      }
    } catch (e) {
      setState(() => _isPreviewLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load route: $e')));
      }
    }
  }

  void _fitMapBoundsForSpots() {
    if (_suggestedWaypoints == null || _suggestedWaypoints!.isEmpty) {
      _fitMapBounds();
      return;
    }
    
    double minLat = widget.origin.lat!;
    double maxLat = widget.origin.lat!;
    double minLng = widget.origin.lng!;
    double maxLng = widget.origin.lng!;

    for (var spot in _suggestedWaypoints!) {
      if (spot.lat < minLat) minLat = spot.lat;
      if (spot.lat > maxLat) maxLat = spot.lat;
      if (spot.lng < minLng) minLng = spot.lng;
      if (spot.lng > maxLng) maxLng = spot.lng;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  void _fitMapBounds() {
    if (_previewRoutes == null || _previewRoutes!.isEmpty) return;

    try {
      final currentRoute = _previewRoutes![_selectedRouteIndex];
      final boundsMap = currentRoute['bounds'] as Map<String, dynamic>?;

      if (boundsMap != null && boundsMap['southwest'] != null && boundsMap['northeast'] != null) {
        final sw = boundsMap['southwest'] as Map<String, dynamic>;
        final ne = boundsMap['northeast'] as Map<String, dynamic>;
        
        if (sw['lat'] != null && sw['lng'] != null && ne['lat'] != null && ne['lng'] != null) {
          final bounds = LatLngBounds(
            LatLng(sw['lat'] as double, sw['lng'] as double),
            LatLng(ne['lat'] as double, ne['lng'] as double),
          );

          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fitting map bounds: $e');
    }
  }

  Future<void> _createTrip() async {
    if (_previewRoutes == null || _previewRoutes!.isEmpty) return;

    setState(() => _isCreating = true);

    try {
      final currentRoute = _previewRoutes![_selectedRouteIndex];
      final legs = currentRoute['legs'] as List;
      
      int totalDistance = 0;
      int totalDuration = 0;
      for (var leg in legs) {
        totalDistance += (leg['distance'] as num).toInt();
        totalDuration += (leg['duration'] as num).toInt();
      }
      
      final polyline = currentRoute['overview_polyline'];

      final groupProvider = context.read<GroupProvider>();
      
      final group = await groupProvider.createGroup(
        name: widget.tripName,
        origin: widget.origin,
        destination: widget.destination,
        transportMode: widget.transportMode,
        routeMode: _selectedRouteMode,
        polyline: polyline,
        distanceMeters: totalDistance,
        durationSeconds: totalDuration,
        aiWaypoints: _previewAiWaypoints,
        routeCharacter: _previewRouteCharacter,
      );

      if (mounted) {
        if (group != null) {
          Navigator.pushNamedAndRemoveUntil(context, '/group-lobby', (route) => route.isFirst, arguments: group.id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(groupProvider.errorMessage ?? 'Failed to create trip')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
                if (_currentStep == 0) {
                  // Wait
                } else if (_currentStep == 1) {
                  _fitMapBoundsForSpots();
                }
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
      ),
      body: Stack(
        children: [
          // Map Background
          _buildMap(),

          // Glassmorphic Overlay Container
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        if (_currentStep == 0) _buildStyleSelectionView(),
                        if (_currentStep == 1) _buildSpotSelectionView(),
                        if (_currentStep == 2) _buildRoutePreviewView(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStyleSelectionView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Choose Your Adventure',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select a route style for ${widget.tripName}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _carouselController,
            onPageChanged: (index) {
              setState(() {
                _currentCarouselIndex = index;
                _selectedRouteMode = _routeModes[index]['id'];
              });
            },
            itemCount: _routeModes.length,
            itemBuilder: (context, index) {
              return _buildStyleCard(index);
            },
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isPreviewLoading ? null : _fetchSuggestedSpots,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              child: _isPreviewLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Find Spots',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSpotSelectionView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              Text(
                'Customize Your Journey',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select spots you\'d like to visit',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_suggestedWaypoints == null || _suggestedWaypoints!.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('No spots found for this route.'),
          )
        else
          SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestedWaypoints!.length,
              itemBuilder: (context, index) {
                final spot = _suggestedWaypoints![index];
                final isSelected = _selectedWaypoints.contains(spot);
                return _buildSpotCard(spot, isSelected);
              },
            ),
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isPreviewLoading ? null : () => _fetchFinalRoute(_selectedWaypoints),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              child: _isPreviewLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Generate Route (${_selectedWaypoints.length} spots)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSpotCard(AIWaypoint spot, bool isSelected) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedWaypoints.remove(spot);
          } else {
            _selectedWaypoints.add(spot);
          }
        });
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (context) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (spot.photoUrl != null && spot.photoUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      spot.photoUrl!.startsWith('//') ? 'https:${spot.photoUrl}' : spot.photoUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(spot),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: _buildPlaceholder(spot),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(spot.emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        spot.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Type: ${spot.type}', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                Text(spot.reason, style: const TextStyle(fontSize: 16, height: 1.5)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 200,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (spot.photoUrl != null && spot.photoUrl!.isNotEmpty)
                      Image.network(
                        spot.photoUrl!.startsWith('//') ? 'https:${spot.photoUrl}' : spot.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(spot),
                      )
                    else
                      _buildPlaceholder(spot),
                    
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Text(spot.emoji, style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                    
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          spot.reason,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPlaceholder(AIWaypoint spot) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4CA1AF), Color(0xFFC4E0E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.landscape, color: Colors.white54, size: 40),
      ),
    );
  }
  
  Widget _buildRoutePreviewView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_previewRouteCharacter != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              _previewRouteCharacter!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        if (_previewRoutes != null && _previewRoutes!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: _buildRouteStats(),
          ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isCreating || _isPreviewLoading ? null : _createTrip,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              child: _isCreating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Confirm and Create Trip',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(widget.origin.lat!, widget.origin.lng!),
        initialZoom: 12.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.rouniity',
        ),
        if (_previewRoutes != null && _previewRoutes!.isNotEmpty && _currentStep == 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: decodePolyline(_previewRoutes![_selectedRouteIndex]['overview_polyline'] ?? _previewRoutes![_selectedRouteIndex]['geometry'] ?? ''),
                color: Theme.of(context).primaryColor,
                strokeWidth: 5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(widget.origin.lat!, widget.origin.lng!),
              width: 32,
              height: 32,
              child: _buildLocationMarker(Icons.my_location, Colors.blue),
            ),
            Marker(
              point: LatLng(widget.destination.lat!, widget.destination.lng!),
              width: 32,
              height: 32,
              child: _buildLocationMarker(Icons.location_on, Colors.red),
            ),
          ],
        ),
        if (_currentStep == 1 && _suggestedWaypoints != null)
          MarkerLayer(
            markers: _suggestedWaypoints!.map((wp) {
              final isSelected = _selectedWaypoints.contains(wp);
              return Marker(
                point: LatLng(wp.lat, wp.lng),
                width: isSelected ? 48 : 36,
                height: isSelected ? 48 : 36,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: Center(
                    child: Text(
                      wp.emoji,
                      style: TextStyle(fontSize: isSelected ? 22 : 16),
                    ),
                  ),
                ),
              );
            }).toList(),
          )
        else if (_previewAiWaypoints != null && _currentStep == 2)
          MarkerLayer(
            markers: _previewAiWaypoints!.map((wp) {
              return Marker(
                point: LatLng(wp.lat, wp.lng),
                width: 40,
                height: 40,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: Center(child: Text(wp.emoji, style: const TextStyle(fontSize: 18))),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildLocationMarker(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          )
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildStyleCard(int index) {
    final mode = _routeModes[index];
    final isSelected = _currentCarouselIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(
        left: index == 0 ? 0 : 8,
        right: index == _routeModes.length - 1 ? 0 : 8,
        top: isSelected ? 0 : 20,
        bottom: isSelected ? 0 : 20,
      ),
      decoration: BoxDecoration(
        gradient: mode['gradient'],
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: (mode['gradient'] as LinearGradient).colors.first.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
        ],
      ),
      child: Stack(
        children: [
          // Background pattern/icon
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              mode['icon'],
              size: 140,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(mode['icon'], color: Colors.white, size: 32),
                ),
                const Spacer(),
                Text(
                  mode['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mode['subtitle'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStats() {
    final route = _previewRoutes![_selectedRouteIndex];
    final legs = route['legs'] as List;
    
    int totalDistanceMeters = 0;
    int totalDurationSeconds = 0;
    for (var leg in legs) {
      totalDistanceMeters += (leg['distance'] as num).toInt();
      totalDurationSeconds += (leg['duration'] as num).toInt();
    }
    
    final distanceText = (totalDistanceMeters / 1000).toStringAsFixed(1) + ' km';
    final durationMins = totalDurationSeconds ~/ 60;
    
    final hours = durationMins ~/ 60;
    final mins = durationMins % 60;
    final durationText = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn(Icons.route_rounded, 'Distance', distanceText),
          Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.2)),
          _buildStatColumn(Icons.timer_rounded, 'Duration', durationText),
        ],
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
