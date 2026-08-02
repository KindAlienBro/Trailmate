import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../services/ola_maps_service.dart';
import '../../services/location_service.dart';
import 'route_style_screen.dart';

/// Ultra-Premium Create Group Screen — Wizard Flow
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  
  final _nameController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  
  final _nameFocus = FocusNode();
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();

  final OlaMapsService _mapsService = OlaMapsService();
  String _selectedMode = 'driving';
  bool _isGeocoding = false;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() {}));
    _fromFocus.addListener(() => setState(() {}));
    _toFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _nameFocus.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0 && _nameController.text.trim().isEmpty) {
      _showError('Please enter a trip name');
      return;
    }
    
    if (_currentPage < 2) {
      FocusScope.of(context).unfocus();
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    } else {
      _handleFinalSubmit();
    }
  }
  
  void _prevPage() {
    if (_currentPage > 0) {
      FocusScope.of(context).unfocus();
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    } else {
      Navigator.pop(context);
    }
  }

  Future<Iterable<String>> _getPlaceSuggestions(String query) async {
    if (query.length < 3) return const Iterable<String>.empty();
    try {
      if (mounted) _mapsService.setToken(context.read<AuthProvider>().token ?? '');
      double? lat;
      double? lng;
      try {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (_) {}

      final result = await _mapsService.autocomplete(input: query, lat: lat, lng: lng);
      final predictions = result['predictions'] as List? ?? [];
      return predictions.map((p) => p['description'] as String).take(5);
    } catch (e) {
      return const Iterable<String>.empty();
    }
  }

  Future<void> _handleFinalSubmit() async {
    if (_fromController.text.trim().isEmpty || _toController.text.trim().isEmpty) {
      _showError('Please set both origin and destination');
      return;
    }

    setState(() => _isGeocoding = true);
    if (mounted) _mapsService.setToken(context.read<AuthProvider>().token ?? '');
    
    PlaceModel origin = PlaceModel(name: _fromController.text.trim(), address: _fromController.text.trim());
    PlaceModel destination = PlaceModel(name: _toController.text.trim(), address: _toController.text.trim());

    try {
      final coordRegex = RegExp(r'^[-+]?\d*\.?\d+,\s*[-+]?\d*\.?\d+$');

      if (coordRegex.hasMatch(origin.name)) {
        final parts = origin.name.split(',');
        origin = PlaceModel(name: origin.name, address: origin.address, lat: double.parse(parts[0].trim()), lng: double.parse(parts[1].trim()));
      } else {
        final fromGeo = await _mapsService.geocode(origin.name);
        if (fromGeo['geocodingResults']?.isNotEmpty == true) {
          final loc = fromGeo['geocodingResults'][0]['geometry']['location'];
          origin = PlaceModel(name: origin.name, address: origin.address, lat: loc['lat'], lng: loc['lng']);
        }
      }
      
      if (coordRegex.hasMatch(destination.name)) {
        final parts = destination.name.split(',');
        destination = PlaceModel(name: destination.name, address: destination.address, lat: double.parse(parts[0].trim()), lng: double.parse(parts[1].trim()));
      } else {
        final toGeo = await _mapsService.geocode(destination.name);
        if (toGeo['geocodingResults']?.isNotEmpty == true) {
          final loc = toGeo['geocodingResults'][0]['geometry']['location'];
          destination = PlaceModel(name: destination.name, address: destination.address, lat: loc['lat'], lng: loc['lng']);
        }
      }

      setState(() => _isGeocoding = false);

      if (origin.hasLocation && destination.hasLocation && mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => RouteStyleScreen(
            tripName: _nameController.text.trim(),
            transportMode: _selectedMode,
            origin: origin,
            destination: destination,
          ),
        ));
      } else {
        _showError('Failed to locate one or more addresses.');
      }
    } catch (e) {
      setState(() => _isGeocoding = false);
      _showError('Error determining locations.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.of(context).accentDanger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient Base
          Container(
            decoration: BoxDecoration(gradient: colors.primaryGradient),
          ),
          
          // Organic Blurry Orbs
          Positioned(
            bottom: -150,
            left: -50,
            child: _buildBlurOrb(colors.accentSecondary, 400),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(colors, theme),
                _buildProgressBar(colors),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _buildStep1Name(colors, theme),
                      _buildStep2Mode(colors, theme),
                      _buildStep3Route(colors, theme),
                    ],
                  ),
                ),
                _buildBottomBar(colors, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildHeader(AppColorScheme colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _prevPage,
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          ),
          Expanded(
            child: Text(
              'Create Trip',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance for centering
        ],
      ),
    );
  }

  Widget _buildProgressBar(AppColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentPage;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? colors.accentPrimary : colors.surfaceColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: colors.accentPrimary.withValues(alpha: 0.4),
                    blurRadius: 8,
                  )
                ] : [],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar(AppColorScheme colors, ThemeData theme) {
    final isLastStep = _currentPage == 2;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.primaryBackground.withValues(alpha: 0.8),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Container(
          decoration: BoxDecoration(
            gradient: colors.accentGradient,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: colors.accentPrimary.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isGeocoding ? null : _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            child: _isGeocoding
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLastStep ? 'Design Route Style' : 'Continue',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(isLastStep ? Icons.palette_rounded : Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ==================== WIZARD PAGES ====================

  Widget _buildStep1Name(AppColorScheme colors, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.accentPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.drive_file_rename_outline, color: colors.accentPrimary, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            'Give your trip\na name',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Something catchy for your group to identify this adventure.',
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 48),
          
          _buildGlowingTextField(
            controller: _nameController,
            focusNode: _nameFocus,
            colors: colors,
            theme: theme,
            label: 'Trip Name',
            icon: Icons.title_rounded,
            textCapitalization: TextCapitalization.words,
            hintText: 'e.g., Weekend Road Trip',
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Mode(AppColorScheme colors, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.accentSecondary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.explore_rounded, color: colors.accentSecondary, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            'How are you\ntraveling?',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select the primary mode of transport to optimize the route.',
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 48),
          
          _buildModeGrid(colors, theme),
        ],
      ),
    );
  }

  Widget _buildStep3Route(AppColorScheme colors, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.accentWarning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.map_rounded, color: colors.accentWarning, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            'Set the\nDestinations',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Where does the adventure begin and end?',
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 40),
          
          _buildLocationField(
            controller: _fromController,
            focusNode: _fromFocus,
            colors: colors,
            theme: theme,
            label: 'Starting Point',
            icon: Icons.my_location_rounded,
            iconColor: colors.accentSecondary,
            onUseCurrentLocation: () => _useCurrentLocation(_fromController),
          ),
          const SizedBox(height: 24),
          _buildLocationField(
            controller: _toController,
            focusNode: _toFocus,
            colors: colors,
            theme: theme,
            label: 'Destination',
            icon: Icons.location_on_rounded,
            iconColor: colors.accentDanger,
          ),
        ],
      ),
    );
  }

  // ==================== WIDGET HELPERS ====================

  Widget _buildModeGrid(AppColorScheme colors, ThemeData theme) {
    final modes = [
      {'id': 'driving', 'icon': Icons.directions_car_rounded, 'label': 'Car'},
      {'id': 'two_wheeler', 'icon': Icons.two_wheeler_rounded, 'label': 'Bike'},
      {'id': 'walking', 'icon': Icons.directions_walk_rounded, 'label': 'Walk'},
      {'id': 'bicycling', 'icon': Icons.directions_bike_rounded, 'label': 'Cycle'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: modes.length,
      itemBuilder: (context, index) {
        final mode = modes[index];
        final isSelected = _selectedMode == mode['id'];
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentPrimary.withValues(alpha: 0.15) : colors.surfaceColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? colors.accentPrimary : colors.borderColor.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: colors.accentPrimary.withValues(alpha: 0.2),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ] : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => setState(() => _selectedMode = mode['id'] as String),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    mode['icon'] as IconData,
                    size: 40,
                    color: isSelected ? colors.accentPrimary : colors.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mode['label'] as String,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? colors.accentPrimary : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlowingTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required AppColorScheme colors,
    required ThemeData theme,
    required String label,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? hintText,
  }) {
    final isFocused = focusNode.hasFocus;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: isFocused ? [
          BoxShadow(
            color: colors.accentPrimary.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ] : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: textCapitalization,
        style: theme.textTheme.bodyLarge?.copyWith(color: colors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: theme.textTheme.bodyMedium?.copyWith(
            color: isFocused ? colors.accentPrimary : colors.textTertiary,
          ),
          prefixIcon: Icon(icon, color: isFocused ? colors.accentPrimary : colors.textTertiary),
          filled: true,
          fillColor: colors.surfaceColor.withValues(alpha: isFocused ? 0.8 : 0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32),
            borderSide: BorderSide(color: colors.borderColor.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32),
            borderSide: BorderSide(color: colors.borderColor.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32),
            borderSide: BorderSide(color: colors.accentPrimary, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required AppColorScheme colors,
    required ThemeData theme,
    required String label,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onUseCurrentLocation,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        return _getPlaceSuggestions(textEditingValue.text);
      },
      onSelected: (String selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (context, textController, currentFocusNode, onFieldSubmitted) {
        // Since we are overriding the controller, we must listen to it to show glow properly
        // For simplicity, we just use the currentFocusNode
        final isFocused = currentFocusNode.hasFocus;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: isFocused ? [
              BoxShadow(color: iconColor.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 2)
            ] : [],
          ),
          child: TextField(
            controller: textController,
            focusNode: currentFocusNode,
            textCapitalization: TextCapitalization.words,
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                color: isFocused ? iconColor : colors.textTertiary,
              ),
              prefixIcon: Icon(icon, color: isFocused ? iconColor : colors.textTertiary),
              suffixIcon: onUseCurrentLocation != null ? IconButton(
                icon: Icon(Icons.gps_fixed, color: colors.accentPrimary),
                onPressed: () {
                  textController.text = "Fetching...";
                  onUseCurrentLocation();
                },
              ) : null,
              filled: true,
              fillColor: colors.surfaceColor.withValues(alpha: isFocused ? 0.8 : 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(color: colors.borderColor.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(color: colors.borderColor.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(color: iconColor, width: 2),
              ),
            ),
            onChanged: (val) {
              controller.text = val; // keep in sync
            },
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: colors.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 64,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                      controller.text = option; // keep in sync
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(option, style: TextStyle(color: colors.textPrimary)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _useCurrentLocation(TextEditingController controller) async {
    final locService = LocationService();
    try {
      final pos = await locService.getCurrentPosition().timeout(const Duration(seconds: 10));
      
      if (pos == null) {
        controller.clear();
        _showError('Failed to get location. Enable GPS or permissions.');
        return;
      }
      
      if (mounted) _mapsService.setToken(context.read<AuthProvider>().token ?? '');
      final res = await _mapsService.reverseGeocode(lat: pos.latitude, lng: pos.longitude).timeout(const Duration(seconds: 10));
      
      if (res['geocodingResults']?.isNotEmpty == true) {
        final addr = res['geocodingResults'][0]['formatted_address'];
        controller.text = addr;
      } else {
        controller.text = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      }
    } catch (e) {
      controller.clear();
      _showError('Location fetch timed out or failed. Please type manually.');
    }
  }
}
