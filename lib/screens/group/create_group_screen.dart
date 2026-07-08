import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart'; // Just for PlaceModel
import '../../services/ola_maps_service.dart';
import '../../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'route_style_screen.dart';

/// Create Group Screen — Step 1: Leader sets group name, transport mode, and endpoints.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final OlaMapsService _mapsService = OlaMapsService();
  String _selectedMode = 'driving';

  bool _isGeocoding = false;

  Future<Iterable<String>> _getPlaceSuggestions(String query) async {
    if (query.length < 3) return const Iterable<String>.empty();
    try {
      if (mounted) {
        _mapsService.setToken(context.read<AuthProvider>().token ?? '');
      }
      double? lat;
      double? lng;
      try {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (_) {}

      final result = await _mapsService.autocomplete(
        input: query,
        lat: lat,
        lng: lng,
      );
      final predictions = result['predictions'] as List? ?? [];
      return predictions.map((p) => p['description'] as String).take(5);
    } catch (e) {
      return const Iterable<String>.empty();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isGeocoding = true);
    if (mounted) {
      _mapsService.setToken(context.read<AuthProvider>().token ?? '');
    }
    
    PlaceModel origin = PlaceModel(name: _fromController.text.trim(), address: _fromController.text.trim());
    PlaceModel destination = PlaceModel(name: _toController.text.trim(), address: _toController.text.trim());

    try {
      final coordRegex = RegExp(r'^[-+]?\d*\.?\d+,\s*[-+]?\d*\.?\d+$');

      if (coordRegex.hasMatch(origin.name)) {
        final parts = origin.name.split(',');
        origin = PlaceModel(
          name: origin.name, 
          address: origin.address, 
          lat: double.parse(parts[0].trim()), 
          lng: double.parse(parts[1].trim())
        );
      } else {
        final fromGeo = await _mapsService.geocode(origin.name);
        if (fromGeo['geocodingResults']?.isNotEmpty == true) {
          final loc = fromGeo['geocodingResults'][0]['geometry']['location'];
          origin = PlaceModel(name: origin.name, address: origin.address, lat: loc['lat'], lng: loc['lng']);
        }
      }
      
      if (coordRegex.hasMatch(destination.name)) {
        final parts = destination.name.split(',');
        destination = PlaceModel(
          name: destination.name, 
          address: destination.address, 
          lat: double.parse(parts[0].trim()), 
          lng: double.parse(parts[1].trim())
        );
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
        _showError('Failed to geocode one or more locations. Please try again.');
      }
    } catch (e) {
      debugPrint('Geocode error: $e');
      setState(() => _isGeocoding = false);
      _showError('Error determining locations.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.accentRed),
    );
  }

  Widget _buildModeButton(IconData icon, String mode, String label) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMode = mode;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentBlue.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.5)) : Border.all(color: Colors.transparent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.accentBlue : AppTheme.textTertiary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.accentBlue : AppTheme.textTertiary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                    ),
                    const Expanded(
                      child: Text(
                        'Create Trip',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero icon
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: AppTheme.accentGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentBlue.withValues(alpha: 0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.group_add_rounded, size: 40, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Center(
                        child: Text(
                          'Start a Group Trip',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Step 1: Set up the trip details',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Form
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: glassCardDecoration(opacity: 0.06),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Trip Name',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                                decoration: const InputDecoration(
                                  hintText: 'e.g., Weekend Road Trip',
                                  prefixIcon: Icon(Icons.drive_file_rename_outline, color: AppTheme.textTertiary),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a trip name';
                                  }
                                  if (value.trim().length < 2) {
                                    return 'Name must be at least 2 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              const Text(
                                'Mode of Transport',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceDark.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.borderDark),
                                ),
                                child: Row(
                                  children: [
                                    _buildModeButton(Icons.directions_car_rounded, 'driving', 'Car'),
                                    _buildModeButton(Icons.two_wheeler_rounded, 'two_wheeler', 'Bike'),
                                    _buildModeButton(Icons.directions_walk_rounded, 'walking', 'Walk'),
                                    _buildModeButton(Icons.directions_bike_rounded, 'bicycling', 'Cycle'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              const Text(
                                'Route Details',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Autocomplete<String>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  return _getPlaceSuggestions(textEditingValue.text);
                                },
                                onSelected: (String selection) {
                                  _fromController.text = selection;
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    textCapitalization: TextCapitalization.words,
                                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                                    decoration: InputDecoration(
                                      hintText: 'From (e.g., New York, NY)',
                                      prefixIcon: const Icon(Icons.my_location_rounded, color: AppTheme.accentGreen),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.gps_fixed, color: AppTheme.accentBlue),
                                        tooltip: 'Use current location',
                                        onPressed: () async {
                                          final locService = LocationService();
                                          final pos = await locService.getCurrentPosition();
                                          
                                          if (pos == null) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Failed to get location. Please enable GPS and Permissions.'), backgroundColor: AppTheme.accentRed),
                                              );
                                            }
                                            return;
                                          }
                                          
                                          try {
                                            controller.text = 'Fetching address...';
                                            if (mounted) _mapsService.setToken(context.read<AuthProvider>().token ?? '');
                                            final res = await _mapsService.reverseGeocode(lat: pos.latitude, lng: pos.longitude);
                                            if (res['geocodingResults']?.isNotEmpty == true) {
                                              final addr = res['geocodingResults'][0]['formatted_address'];
                                              controller.text = addr;
                                              _fromController.text = addr;
                                            } else {
                                              final locStr = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
                                              controller.text = locStr;
                                              _fromController.text = locStr;
                                            }
                                          } catch (e) {
                                            debugPrint('Reverse Geocode Error: $e');
                                            final locStr = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
                                            controller.text = locStr;
                                            _fromController.text = locStr;
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Could not fetch address name, using coordinates instead.'), backgroundColor: AppTheme.accentPurple),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                    onChanged: (val) => _fromController.text = val,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter a starting location';
                                      }
                                      return null;
                                    },
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 8,
                                      color: AppTheme.surfaceDark,
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: MediaQuery.of(context).size.width - 96,
                                        child: ListView.builder(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (BuildContext context, int index) {
                                            final String option = options.elementAt(index);
                                            return InkWell(
                                              onTap: () {
                                                onSelected(option);
                                                _fromController.text = option;
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(16.0),
                                                child: Text(option, style: const TextStyle(color: AppTheme.textPrimary)),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Autocomplete<String>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  return _getPlaceSuggestions(textEditingValue.text);
                                },
                                onSelected: (String selection) {
                                  _toController.text = selection;
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    textCapitalization: TextCapitalization.words,
                                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                                    decoration: const InputDecoration(
                                      hintText: 'To (e.g., Boston, MA)',
                                      prefixIcon: Icon(Icons.location_on_rounded, color: AppTheme.accentRed),
                                    ),
                                    onChanged: (val) => _toController.text = val,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter a destination';
                                      }
                                      return null;
                                    },
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 8,
                                      color: AppTheme.surfaceDark,
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: MediaQuery.of(context).size.width - 96,
                                        child: ListView.builder(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (BuildContext context, int index) {
                                            final String option = options.elementAt(index);
                                            return InkWell(
                                              onTap: () {
                                                onSelected(option);
                                                _toController.text = option;
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(16.0),
                                                child: Text(option, style: const TextStyle(color: AppTheme.textPrimary)),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 32),

                              // Next button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: Container(
                                  decoration: accentButtonDecoration(),
                                  child: ElevatedButton(
                                    onPressed: _isGeocoding ? null : _handleNext,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _isGeocoding
                                        ? const SizedBox(
                                            width: 22, height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Next: Choose Route Style',
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
