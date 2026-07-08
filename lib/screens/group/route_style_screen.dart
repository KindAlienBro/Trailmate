import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
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
  
  String _selectedRouteMode = 'highway';
  
  bool _isPreviewLoading = false;
  List<dynamic>? _previewRoutes;
  int _selectedRouteIndex = 0;
  LatLng? _previewOrigin;
  LatLng? _previewDestination;
  List<AIWaypoint>? _previewAiWaypoints;
  String? _previewRouteCharacter;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Default origin and destination for initial map view before fetching route
    _previewOrigin = LatLng(widget.origin.lat!, widget.origin.lng!);
    _previewDestination = LatLng(widget.destination.lat!, widget.destination.lng!);
    
    // Auto fetch highway route on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRoutePreview();
    });
  }

  Future<void> _fetchRoutePreview() async {
    setState(() => _isPreviewLoading = true);
    _mapsService.setToken(context.read<AuthProvider>().token ?? '');

    try {
      final Map<String, dynamic> dir;
      List<AIWaypoint> aiWaypoints = [];
      String? routeCharacter;

      if (_selectedRouteMode != 'highway') {
        dir = await _mapsService.getSmartRoute(
          originLat: widget.origin.lat!,
          originLng: widget.origin.lng!,
          destLat: widget.destination.lat!,
          destLng: widget.destination.lng!,
          mode: _selectedRouteMode,
          transportMode: widget.transportMode,
        );
        final aiWaypointsJson = dir['aiWaypoints'] as List? ?? [];
        aiWaypoints = aiWaypointsJson
            .map((w) => AIWaypoint.fromJson(Map<String, dynamic>.from(w)))
            .toList();
        routeCharacter = dir['routeCharacter'] as String?;
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

      if (!mounted) return;

      if (dir['routes'] != null && (dir['routes'] as List).isNotEmpty) {
        final routes = dir['routes'] as List;
        setState(() {
          _previewRoutes = routes;
          _selectedRouteIndex = 0;
          _previewAiWaypoints = aiWaypoints;
          _previewRouteCharacter = routeCharacter;
        });

        _fitBounds();
      } else {
        _showError('No routes found.');
      }
    } catch (e) {
      debugPrint('Directions error: $e');
      _showError('Failed to get directions.');
    } finally {
      if (mounted) {
        setState(() => _isPreviewLoading = false);
      }
    }
  }

  void _fitBounds() {
    if (_previewOrigin != null && _previewDestination != null && _previewRoutes != null && _previewRoutes!.isNotEmpty) {
      try {
        final bounds = LatLngBounds.fromPoints([
          _previewOrigin!,
          _previewDestination!,
          ...decodePolyline(_previewRoutes![0]['overview_polyline'] ?? _previewRoutes![0]['geometry'] ?? ''),
        ]);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.only(left: 40, right: 40, top: 80, bottom: 350), // bottom padding for cards
          ),
        );
      } catch (e) {
        debugPrint('Fit bounds error: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.accentRed),
    );
  }

  Future<void> _handleCreateGroup() async {
    if (_previewRoutes == null || _previewRoutes!.isEmpty) {
      _showError('Please wait for the route to load.');
      return;
    }

    setState(() => _isCreating = true);
    final groupProvider = context.read<GroupProvider>();
    groupProvider.setToken(context.read<AuthProvider>().token);

    final route = _previewRoutes![_selectedRouteIndex];
    String? polyline = route['overview_polyline'] ?? route['geometry'];
    int? distanceMeters;
    int? durationSeconds;

    if (route['legs']?.isNotEmpty == true) {
      final leg = route['legs'][0];
      distanceMeters = leg['distance'];
      durationSeconds = leg['duration'];
    }

    final group = await groupProvider.createGroup(
      name: widget.tripName,
      origin: widget.origin,
      destination: widget.destination,
      polyline: polyline,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      transportMode: widget.transportMode,
      routeMode: _selectedRouteMode,
      aiWaypoints: _previewAiWaypoints,
      routeCharacter: _previewRouteCharacter,
    );

    setState(() => _isCreating = false);

    if (group != null && mounted) {
      // Pop until the home screen, then push lobby
      Navigator.of(context).pop(); // pop this screen
      Navigator.of(context).pushReplacementNamed('/group-lobby', arguments: group.id);
    }
  }

  Widget _buildRouteModeCard({
    required String mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
  }) {
    final isSelected = _selectedRouteMode == mode;
    return GestureDetector(
      onTap: () {
        if (_selectedRouteMode == mode) return;
        setState(() {
          _selectedRouteMode = mode;
        });
        _fetchRoutePreview();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 280, // Fixed width for horizontal scrolling
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(right: 12), // Change margin for horizontal spacing
        decoration: BoxDecoration(
          gradient: isSelected ? gradient : null,
          color: isSelected ? null : AppTheme.surfaceDark.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white.withValues(alpha: 0.3) : AppTheme.borderDark,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : AppTheme.textTertiary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white.withValues(alpha: 0.8) : AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : AppTheme.textTertiary,
                  width: 2,
                ),
                color: isSelected ? Colors.white : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Color(0xFF1B5E20))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLayer() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _previewOrigin ?? const LatLng(0, 0),
        initialZoom: 12.0,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.trialmate',
        ),
        if (_previewRoutes != null && _previewRoutes!.isNotEmpty)
          PolylineLayer(
            polylines: [
              // Draw unselected routes first so they are underneath
              for (int i = 0; i < _previewRoutes!.length; i++)
                if (i != _selectedRouteIndex)
                  Polyline(
                    points: decodePolyline(_previewRoutes![i]['overview_polyline'] ?? _previewRoutes![i]['geometry'] ?? ''),
                    color: Colors.grey.withValues(alpha: 0.6),
                    strokeWidth: 4.0,
                  ),
              // Draw selected route on top
              Polyline(
                points: decodePolyline(_previewRoutes![_selectedRouteIndex]['overview_polyline'] ?? _previewRoutes![_selectedRouteIndex]['geometry'] ?? ''),
                color: AppTheme.accentBlue,
                strokeWidth: 5.0,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (_previewOrigin != null)
              Marker(
                point: _previewOrigin!,
                width: 40, height: 40,
                child: const Icon(Icons.location_on, color: AppTheme.accentGreen, size: 40),
              ),
            if (_previewDestination != null)
              Marker(
                point: _previewDestination!,
                width: 40, height: 40,
                child: const Icon(Icons.location_on, color: AppTheme.accentRed, size: 40),
              ),
            if (_previewAiWaypoints != null)
              for (var wp in _previewAiWaypoints!)
                Marker(
                  point: LatLng(wp.lat, wp.lng),
                  width: 40, height: 40,
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentPurple.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(wp.emoji, style: const TextStyle(fontSize: 24)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          wp.name,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        Text(
                                          wp.type.toUpperCase().replaceAll('_', ' '),
                                          style: TextStyle(fontSize: 12, color: AppTheme.accentPurple.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                wp.reason,
                                style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.4),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentPurple.withValues(alpha: 0.2),
                                    foregroundColor: AppTheme.accentPurple,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.accentPurple,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.star, color: Colors.white, size: 20),
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Stack(
        children: [
          // Background Full Map
          Positioned.fill(
            child: _buildMapLayer(),
          ),
          
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
              ),
            ),
          ),

          // Loading overlay
          if (_isPreviewLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Generating Route...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),

          // Multiple Routes Selector
          if (_previewRoutes != null && _previewRoutes!.length > 1 && !_isPreviewLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 60,
              right: 16,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_previewRoutes!.length, (index) {
                    final route = _previewRoutes![index];
                    final leg = route['legs']?[0];
                    final duration = leg?['duration'] ?? 0;
                    final timeString = '${(duration / 60).round()} min';
                    
                    final isSelected = index == _selectedRouteIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Route ${index + 1} ($timeString)'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedRouteIndex = index);
                        },
                        selectedColor: AppTheme.accentBlue.withValues(alpha: 0.4),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        backgroundColor: AppTheme.surfaceDark.withValues(alpha: 0.9),
                      ),
                    );
                  }),
                ),
              ),
            ),

          // Bottom Cards Container
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 32),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -5)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Route Style',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100, // Fixed height to contain the horizontal list
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildRouteModeCard(
                          mode: 'highway',
                          icon: Icons.speed_rounded,
                          title: '🛣️  Highway',
                          subtitle: 'Fastest route. No detours.',
                          gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
                        ),
                        _buildRouteModeCard(
                          mode: 'adventure',
                          icon: Icons.terrain_rounded,
                          title: '🏔️  Adventure',
                          subtitle: 'Scenic detours, ghats & hill routes.',
                          gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)]),
                        ),
                        _buildRouteModeCard(
                          mode: 'full_adventure',
                          icon: Icons.explore_rounded,
                          title: '🌊  Full Adventure',
                          subtitle: 'Jungle trails, water crossings.',
                          gradient: const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFBF360C)]),
                        ),
                        _buildRouteModeCard(
                          mode: 'cultural',
                          icon: Icons.account_balance_rounded,
                          title: '🕌  Cultural & Heritage',
                          subtitle: 'Museums, ancient temples, monuments.',
                          gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)]),
                        ),
                        _buildRouteModeCard(
                          mode: 'foodie',
                          icon: Icons.restaurant_rounded,
                          title: '🍕  Foodie Route',
                          subtitle: 'Famous eateries, cafes, bakeries.',
                          gradient: const LinearGradient(colors: [Color(0xFFD84315), Color(0xFFBF360C)]),
                        ),
                        _buildRouteModeCard(
                          mode: 'coastal',
                          icon: Icons.beach_access_rounded,
                          title: '🏖️  Coastal Route',
                          subtitle: 'Beaches, marinas, scenic coastlines.',
                          gradient: const LinearGradient(colors: [Color(0xFF00838F), Color(0xFF006064)]),
                        ),
                        _buildRouteModeCard(
                          mode: 'spiritual',
                          icon: Icons.self_improvement_rounded,
                          title: '🧘  Spiritual Route',
                          subtitle: 'Ashrams, monasteries, retreats.',
                          gradient: const LinearGradient(colors: [Color(0xFFF9A825), Color(0xFFF57F17)]),
                        ),
                        _buildRouteModeCard(
                          mode: 'wildlife',
                          icon: Icons.pets_rounded,
                          title: '🐅  Wildlife Escape',
                          subtitle: 'National parks, reserves, deep forests.',
                          gradient: const LinearGradient(colors: [Color(0xFF33691E), Color(0xFF1B5E20)]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Confirm & Create Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: Container(
                      decoration: accentButtonDecoration(),
                      child: ElevatedButton(
                        onPressed: (_isPreviewLoading || _isCreating) ? null : _handleCreateGroup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isCreating
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text(
                                'Confirm & Create Trip',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
