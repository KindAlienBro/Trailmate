import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/explore_service.dart';
import 'destination_details_screen.dart';

class SearchDestinationsScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchDestinationsScreen({super.key, this.initialQuery});

  @override
  State<SearchDestinationsScreen> createState() => _SearchDestinationsScreenState();
}

class _SearchDestinationsScreenState extends State<SearchDestinationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  List<TouristPlace> _results = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final token = context.read<AuthProvider>().token;
      final results = await ExploreService.searchDestinations(query: query, token: token);
      if (mounted) {
        setState(() {
          _results = results;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onResultTapped(TouristPlace place) {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DestinationDetailsScreen(place: place),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceColor,
      appBar: AppBar(
        backgroundColor: colors.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: widget.initialQuery == null,
          style: TextStyle(color: colors.textPrimary, fontSize: 16),
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search destinations, places...',
            hintStyle: TextStyle(color: colors.textSecondary),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: colors.textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.accentPrimary))
          : _results.isEmpty && _searchController.text.isNotEmpty
              ? Center(
                  child: Text(
                    'No results found',
                    style: TextStyle(color: colors.textSecondary, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _results.length,
                  separatorBuilder: (c, i) => Divider(color: colors.borderColor.withValues(alpha: 0.5), height: 1),
                  itemBuilder: (context, index) {
                    final place = _results[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: place.imageUrl.isNotEmpty
                            ? Image.network(
                                place.imageUrl,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (c,e,s) => Container(
                                  width: 56,
                                  height: 56,
                                  color: colors.cardColor,
                                  child: Icon(Icons.place_rounded, color: colors.textTertiary),
                                ),
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                color: colors.cardColor,
                                child: Icon(Icons.place_rounded, color: colors.textTertiary),
                              ),
                      ),
                      title: Text(
                        place.name,
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      subtitle: Text(
                        'Destination',
                        style: TextStyle(color: colors.textSecondary, fontSize: 14),
                      ),
                      onTap: () => _onResultTapped(place),
                    );
                  },
                ),
    );
  }
}
