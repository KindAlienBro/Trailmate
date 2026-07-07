import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/alert_banner.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/poi_card.dart';
import '../../widgets/directions_banner.dart';
import '../../widgets/rerouting_banner.dart';
import '../../widgets/trip_bottom_sheet.dart';
import '../../widgets/map_widget.dart';
import 'arrival_screen.dart';

/// Main Live Navigation Screen
///
/// Combines the TrailMap, alerts overlay, SOS button, member list drawer, and POI cards.
class LiveNavigationScreen extends StatefulWidget {
  final String groupId;

  const LiveNavigationScreen({super.key, required this.groupId});

  @override
  State<LiveNavigationScreen> createState() => _LiveNavigationScreenState();
}

enum NavigationState { browsing, preview, active }
enum MapOrientation { headingUp, northUp, free }

class _LiveNavigationScreenState extends State<LiveNavigationScreen> with TickerProviderStateMixin {
  late MapController _mapController;
  AnimationController? _mapAnimController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  NavigationState _navState = NavigationState.browsing;
  MapOrientation _mapOrientation = MapOrientation.headingUp;
  
  StreamSubscription? _positionSub;
  StreamSubscription? _compassSub;
  double _deviceHeading = 0.0;
  bool _hasCalculatedPreview = false;
  bool _userPannedMap = false; // Track if user dragged the map
  NavigationProvider? _navProvider;
  void _onNavProviderChanged() {
    if (!mounted || _navProvider == null) return;
    if (_navProvider!.routePolyline.isNotEmpty && _navState == NavigationState.browsing && !_hasCalculatedPreview) {
      setState(() {
        _navState = NavigationState.preview;
        _hasCalculatedPreview = true;
      });
      _fitRouteBounds(_navProvider!.routePolyline);
    }
    if (_navProvider!.routePolyline.isEmpty) {
      _hasCalculatedPreview = false;
    }
  }


  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = context.read<NavigationProvider>();
      _navProvider = nav;
      // Hardware compass for accurate heading when stationary
      _compassSub = FlutterCompass.events?.listen((event) {
        if (mounted && event.heading != null) {
          setState(() => _deviceHeading = event.heading!);
          if (_navState == NavigationState.active && _mapOrientation == MapOrientation.headingUp && !_userPannedMap) {
             final pos = nav.locationService.lastPosition;
             // Rotate map using device compass if stationary
             if (pos != null && pos.speed < 1.0) {
               _mapController.rotate(-_deviceHeading);
             }
          }
        }
      });

      // Listen to position updates to auto-follow user with SMOOTH animation
      _positionSub = nav.locationService.positionStream.listen((pos) {
        if (_navState == NavigationState.active && mounted && !_userPannedMap) {
          final speedKmh = pos.speed * 3.6;
          
          // Speed-based auto-zoom
          double targetZoom = _calculateZoomForSpeed(speedKmh);
          
          if (_mapOrientation == MapOrientation.headingUp) {
            double heading = pos.heading;
            if (pos.speed < 1.0) {
              heading = _deviceHeading;
            }
            // Smooth animated move instead of instant snap
            _animatedMapMove(
              LatLng(pos.latitude, pos.longitude),
              targetZoom,
              -heading,
            );
          } else if (_mapOrientation == MapOrientation.northUp) {
            _animatedMapMove(
              LatLng(pos.latitude, pos.longitude),
              targetZoom,
              0.0,
            );
          }
          // In free mode, don't follow
        }
      });
      
      // Listen to nav provider changes to trigger preview when route is generated
      nav.addListener(_onNavProviderChanged);
    });
  }

  /// Calculate zoom level based on driving speed
  double _calculateZoomForSpeed(double speedKmh) {
    if (speedKmh > 80) return 15.0;      // Highway: see far ahead
    if (speedKmh > 50) return 16.0;      // Fast road
    if (speedKmh > 25) return 17.0;      // City driving
    return 18.0;                          // Slow/stationary: detailed view
  }

  void _fitRouteBounds(List<LatLng> polyline) {
    if (polyline.isEmpty) return;
    
    final bounds = LatLngBounds.fromPoints(polyline);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)));
    _mapController.rotate(0);
  }

  void _animatedMapMove(LatLng destLocation, double destZoom, double destRotation) {
    _mapAnimController?.dispose(); // Cancel any existing animation
    
    _mapAnimController = AnimationController(
      duration: const Duration(milliseconds: 500), // Smooth 500ms glide
      vsync: this,
    );

    final latTween = Tween<double>(begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    // Calculate shortest rotation path
    double beginRot = _mapController.camera.rotation;
    double endRot = destRotation;
    final double diff = (endRot - beginRot) % 360;
    if (diff > 180) {
      endRot -= 360;
    } else if (diff < -180) {
      endRot += 360;
    } else {
      endRot = beginRot + diff;
    }
    final rotTween = Tween<double>(begin: beginRot, end: endRot);

    final animation = CurvedAnimation(parent: _mapAnimController!, curve: Curves.easeInOut);

    _mapAnimController!.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
      _mapController.rotate(rotTween.evaluate(animation));
    });

    _mapAnimController!.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _mapAnimController?.dispose();
        _mapAnimController = null;
      }
    });

    _mapAnimController!.forward();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    _mapAnimController?.dispose();
    _navProvider?.removeListener(_onNavProviderChanged);
    super.dispose();
  }

  void _centerOnMe() {
    setState(() {
      _userPannedMap = false;
    });

    if (_navState == NavigationState.preview) {
      setState(() {
        _navState = NavigationState.active;
        _mapOrientation = MapOrientation.headingUp;
      });
    } else {
      setState(() => _mapOrientation = MapOrientation.headingUp);
    }
    
    final nav = context.read<NavigationProvider>();
    final me = nav.locationService.lastPosition;
    if (me != null) {
      double heading = me.heading;
      if (me.speed < 1.0) {
        heading = _deviceHeading;
      }
      _animatedMapMove(LatLng(me.latitude, me.longitude), 18.0, -heading);
    }
  }

  void _toggleMapOrientation() {
    setState(() {
      _userPannedMap = false;
      if (_mapOrientation == MapOrientation.headingUp) {
        _mapOrientation = MapOrientation.northUp;
        _animatedMapMove(_mapController.camera.center, _mapController.camera.zoom, 0.0);
      } else if (_mapOrientation == MapOrientation.northUp) {
        _mapOrientation = MapOrientation.free;
      } else {
        _mapOrientation = MapOrientation.headingUp;
        final nav = context.read<NavigationProvider>();
        final me = nav.locationService.lastPosition;
        if (me != null) {
          double heading = me.heading;
          if (me.speed < 1.0) {
            heading = _deviceHeading;
          }
          _animatedMapMove(_mapController.camera.center, _mapController.camera.zoom, -heading);
        }
      }
    });
  }

  void _triggerSos() {
    final nav = context.read<NavigationProvider>();
    final me = nav.locationService.lastPosition;
    nav.wsService.triggerSOS(
      groupId: widget.groupId,
      lat: me?.latitude,
      lng: me?.longitude,
    );
  }

  void _cancelSos() {
    context.read<NavigationProvider>().wsService.cancelSOS(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildMembersDrawer(context),
      body: Consumer3<NavigationProvider, GroupProvider, AuthProvider>(
        builder: (context, navProvider, groupProvider, authProvider, _) {
          final currentUserId = authProvider.currentUser?.id;
          final leaderId = groupProvider.currentGroup?.leaderId;
          
          // Determine initial center
          LatLng center = const LatLng(20.5937, 78.9629); // India center default
          if (navProvider.locationService.lastPosition != null) {
            center = LatLng(
              navProvider.locationService.lastPosition!.latitude,
              navProvider.locationService.lastPosition!.longitude,
            );
          } else if (navProvider.routePolyline.isNotEmpty) {
            center = navProvider.routePolyline.first;
          }

          return Stack(
            children: [
              // 1. Map Layer — detect user pan gestures
              GestureDetector(
                onPanStart: (_) {
                  if (_navState == NavigationState.active && _mapOrientation != MapOrientation.free) {
                    setState(() {
                      _userPannedMap = true;
                    });
                  }
                },
                child: TrailMapWidget(
                  mapController: _mapController,
                  initialCenter: center,
                  routePolyline: navProvider.routePolyline,
                  memberPositions: navProvider.memberPositions,
                  currentUserId: currentUserId,
                  leaderId: leaderId,
                  isDrivingMode: _navState == NavigationState.active,
                  initialRouteBearing: navProvider.initialRouteBearing,
                  deviceHeading: _deviceHeading,
                ),
              ),

              // 2. Top Bar Layer (or Directions Banner if Driving)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_navState == NavigationState.active)
                        navProvider.isRerouting
                            ? const ReroutingBanner()
                            : DirectionsBanner(
                                currentStep: navProvider.currentStep,
                                distanceToNextManeuver: navProvider.distanceToNextStep,
                              )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Drawer button
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.cardDark.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.borderDark),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.people_alt_rounded, color: AppTheme.textPrimary),
                                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                                ),
                              ),
                              
                              // Exit button
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.cardDark.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.borderDark),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
                                  onPressed: () {
                                    navProvider.stopNavigation();
                                    setState(() {
                                      _navState = NavigationState.browsing;
                                      _mapOrientation = MapOrientation.free;
                                    });
                                    Navigator.of(context).pushReplacementNamed('/home');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 2.5 Alert Banners Layer
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: _navState == NavigationState.active ? 120 : 60), // Sit below the top bar/banner
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...navProvider.activeAlerts.asMap().entries.map((entry) {
                              return AlertBanner(
                                alert: entry.value,
                                onDismiss: () => navProvider.dismissAlert(entry.key),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Floating Action Buttons (Glassmorphism Pill)
              SafeArea(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // SOS Button
                              SosButton(
                                isActive: navProvider.isSosActive && navProvider.sosUserId == currentUserId,
                                onTrigger: _triggerSos,
                                onCancel: _cancelSos,
                              ),
                              const SizedBox(height: 16),
                              Container(height: 1, width: 30, color: Colors.white.withValues(alpha: 0.1)),
                              const SizedBox(height: 16),
                              // TTS Toggle
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    navProvider.ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                    color: navProvider.ttsEnabled ? AppTheme.accentGreen : AppTheme.textSecondary, 
                                    size: 28,
                                  ),
                                  onPressed: navProvider.toggleTts,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Compass Orientation
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _mapOrientation == MapOrientation.headingUp ? Icons.explore_rounded : 
                                    (_mapOrientation == MapOrientation.northUp ? Icons.explore_off_rounded : Icons.threesixty_rounded),
                                    color: AppTheme.accentBlue, 
                                    size: 28,
                                  ),
                                  onPressed: _toggleMapOrientation,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Center on me
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.my_location_rounded, color: AppTheme.accentBlue, size: 28),
                                  onPressed: _centerOnMe,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3.5 Floating "Re-center" button when user panned away
              if (_userPannedMap && _navState == NavigationState.active)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 180),
                      child: GestureDetector(
                        onTap: _centerOnMe,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentBlue.withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Re-center',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 4. Bottom Layer
              if (_navState == NavigationState.active)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TripBottomSheet(
                    distanceRemaining: navProvider.remainingDistance > 0 ? navProvider.remainingDistance : navProvider.routeDistance,
                    durationRemaining: navProvider.remainingDuration > 0 ? navProvider.remainingDuration : navProvider.routeDuration,
                    currentSpeed: navProvider.memberPositions[currentUserId]?.speed ?? 0,
                    onExit: () {
                      navProvider.stopNavigation();
                      setState(() {
                         _navState = NavigationState.browsing;
                         _mapOrientation = MapOrientation.free;
                      });
                    },
                  ),
                )
              else if (_navState == NavigationState.preview)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.borderDark),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))
                          ]
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildDashboardStat(Icons.directions_car_rounded, 'Distance', '${(navProvider.routeDistance / 1000).toStringAsFixed(1)} km'),
                                Container(width: 1, height: 40, color: AppTheme.borderDark),
                                _buildDashboardStat(Icons.timer_rounded, 'ETA', '${(navProvider.routeDuration / 60).toStringAsFixed(0)} min'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: Container(
                                decoration: accentButtonDecoration(),
                                child: ElevatedButton(
                                  onPressed: _centerOnMe,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.navigation_rounded, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('Start Navigation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else if (navProvider.nearbyPlaces.isNotEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Container(
                      height: 120,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: navProvider.nearbyPlaces.length,
                        itemBuilder: (context, index) {
                          return PoiCard(
                            place: navProvider.nearbyPlaces[index],
                            onTap: () {
                              final place = navProvider.nearbyPlaces[index];
                              if (place.lat != null && place.lng != null) {
                                _mapController.move(LatLng(place.lat!, place.lng!), 16.0);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),

              // 5. Arrival Overlay
              if (navProvider.hasArrived)
                ArrivalScreen(
                  totalDistance: navProvider.totalDistanceTraveled,
                  tripDuration: navProvider.tripStartTime != null 
                      ? DateTime.now().difference(navProvider.tripStartTime!)
                      : Duration.zero,
                  onDone: () {
                    navProvider.dismissArrival();
                    navProvider.stopNavigation();
                    setState(() {
                      _navState = NavigationState.browsing;
                      _mapOrientation = MapOrientation.free;
                    });
                    Navigator.of(context).pushReplacementNamed('/home');
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDashboardStat(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildMembersDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.primaryDark,
      child: SafeArea(
        child: Consumer2<NavigationProvider, GroupProvider>(
          builder: (context, navProvider, groupProvider, _) {
            final group = groupProvider.currentGroup;
            if (group == null) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Live Locations',
                        style: TextStyle(fontSize: 14, color: AppTheme.accentBlue),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppTheme.borderDark),
                Expanded(
                  child: ListView.builder(
                    itemCount: group.members.length,
                    itemBuilder: (context, index) {
                      final member = group.members[index];
                      final pos = navProvider.memberPositions[member.userId];
                      
                      // Status color
                      Color statusColor = AppTheme.textSecondary;
                      if (pos != null) {
                        if (pos.status == 'sos') {
                          statusColor = AppTheme.accentRed;
                        } else if (pos.status == 'deviated' || pos.status == 'separated') {
                          statusColor = AppTheme.accentOrange;
                        } else {
                          statusColor = AppTheme.accentGreen;
                        }
                      }

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.cardDark,
                            shape: BoxShape.circle,
                            border: Border.all(color: statusColor, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                          ),
                        ),
                        title: Text(member.name, style: const TextStyle(color: AppTheme.textPrimary)),
                        subtitle: Text(
                          pos != null ? '${pos.speed.toStringAsFixed(0)} km/h • ${pos.status}' : 'Waiting for GPS...',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        onTap: () {
                          if (pos != null) {
                            Navigator.pop(context); // Close drawer
                            _mapController.move(pos.latLng, 16.0);
                          }
                        },
                      );
                    },
                  ),
                ),
                
                // Fetch Nearby POIs tools
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Find Nearby',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildPoiButton(context, 'Fuel', Icons.local_gas_station_rounded, 'gas_station'),
                          _buildPoiButton(context, 'Food', Icons.restaurant_rounded, 'restaurant'),
                          _buildPoiButton(context, 'Hospital', Icons.local_hospital_rounded, 'hospital'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPoiButton(BuildContext context, String label, IconData icon, String type) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context); // close drawer
        final nav = context.read<NavigationProvider>();
        final pos = nav.locationService.lastPosition;
        if (pos != null) {
          await nav.fetchNearbyPlaces(pos.latitude, pos.longitude, type);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Icon(icon, color: AppTheme.accentBlue),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
