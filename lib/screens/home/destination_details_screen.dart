import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../widgets/skeleton_loader.dart';
import '../../providers/auth_provider.dart';
import '../../services/explore_service.dart';
import '../../services/wikipedia_service.dart';

class DestinationDetailsScreen extends StatefulWidget {
  final TouristPlace place;
  
  const DestinationDetailsScreen({super.key, required this.place});

  @override
  State<DestinationDetailsScreen> createState() => _DestinationDetailsScreenState();
}

class _DestinationDetailsScreenState extends State<DestinationDetailsScreen> {
  String _description = '';
  bool _isLoadingDesc = true;
  TouristPlace? _resolvedPlace;
  bool _isResolvingCoords = false;
  bool _isAddressExpanded = false;

  @override
  void initState() {
    super.initState();
    _resolvedPlace = widget.place;
    _fetchDescription();
    if (_resolvedPlace!.lat == 0.0 && _resolvedPlace!.lon == 0.0) {
      _resolveCoordinates();
    }
  }

  Future<void> _fetchDescription() async {
    final desc = await WikipediaService.fetchDescription(widget.place.name);
    if (mounted) {
      setState(() {
        _description = desc;
        _isLoadingDesc = false;
      });
    }
  }

  Future<void> _resolveCoordinates() async {
    setState(() {
      _isResolvingCoords = true;
    });
    try {
      final token = context.read<AuthProvider>().token;
      final resolved = await ExploreService.geocodePlace(widget.place.name, token: token);
      if (resolved != null && mounted) {
        setState(() {
          _resolvedPlace = TouristPlace(
            name: widget.place.name,
            lat: resolved.lat,
            lon: resolved.lon,
            type: widget.place.type,
            distanceKm: widget.place.distanceKm,
            imageUrl: widget.place.imageUrl,
          );
        });
      }
    } catch (e) {
      debugPrint('Failed to resolve coordinates: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingCoords = false;
        });
      }
    }
  }

  void _onNavigate() {
    if (_resolvedPlace!.lat == 0.0 && _resolvedPlace!.lon == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find location coordinates for navigation.')),
      );
      return;
    }
    
    // Using Navigator.push to SmartRouteScreen directly without needing to go to home and switch tabs.
    // However, if SmartRouteScreen expects to be in a main tab, we might just open it directly here.
    Navigator.of(context).pushNamed(
      '/create-group',
      arguments: {'destinationName': _resolvedPlace!.name},
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;
    
    final firstCommaIndex = widget.place.name.indexOf(',');
    final String heading = firstCommaIndex != -1 
        ? widget.place.name.substring(0, firstCommaIndex).trim() 
        : widget.place.name;
    final String address = firstCommaIndex != -1 
        ? widget.place.name.substring(firstCommaIndex + 1).trim() 
        : '';

    return Scaffold(
      backgroundColor: colors.surfaceColor,
      body: Stack(
        children: [
          // Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Image Header
              SliverAppBar(
                expandedHeight: size.height * 0.45,
                pinned: true,
                backgroundColor: colors.surfaceColor,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'place_${widget.place.name}',
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.place.imageUrl.isNotEmpty
                            ? Image.network(
                                widget.place.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(color: colors.cardColor),
                              )
                            : Container(color: colors.cardColor),
                        // Gradient Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.8),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                        // Title at the bottom of the image
                        Positioned(
                          bottom: 24,
                          left: 20,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                heading,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isAddressExpanded = !_isAddressExpanded;
                                    });
                                  },
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_city_rounded, color: Colors.white70, size: 16),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          address,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70,
                                            height: 1.3,
                                          ),
                                          maxLines: _isAddressExpanded ? null : 1,
                                          overflow: _isAddressExpanded ? null : TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        _isAddressExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (widget.place.distanceKm > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.place.distanceKm} km away',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _isLoadingDesc
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: SkeletonTextParagraph(lineCount: 5),
                            )
                          : Text(
                              _description,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: colors.textSecondary,
                              ),
                            ),
                      const SizedBox(height: 100), // padding for bottom button
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Sticky Bottom Navigation Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: colors.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: ElevatedButton(
                onPressed: _isResolvingCoords ? null : _onNavigate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isResolvingCoords
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.directions_rounded, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      _isResolvingCoords ? 'Locating...' : 'Navigate Here',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
