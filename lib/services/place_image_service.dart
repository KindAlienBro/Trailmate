import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Fetches the real, location-specific photo for any place using the Wikipedia API.
/// Results are cached in-memory so repeated calls are instant.
class PlaceImageService {
  // Cache the Future itself to prevent duplicate inflight network requests
  static final Map<String, Future<String>> _cache = {};

  /// Fetches a real photo URL for [placeName].
  /// Hard deadline of 5 s total — returns '' on timeout so the UI never hangs.
  static Future<String> fetchImageUrl(
    String placeName, {
    double? lat,
    double? lon,
  }) {
    final cacheKey = '${placeName}_${lat ?? ''}_${lon ?? ''}';
    
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }
    if (_cache.containsKey(placeName)) {
      return _cache[placeName]!;
    }

    final future = _fetchWithTimeout(placeName, lat, lon).then((result) {
      debugPrint('PlaceImageService: "$placeName" → '
          '${result.isNotEmpty ? result.substring(0, result.length.clamp(0, 80)) : "EMPTY"}');
      
      // If it failed completely, remove it from cache so we can try again later
      if (result.isEmpty) {
        _cache.remove(cacheKey);
        _cache.remove(placeName);
      }
      return result;
    });

    _cache[cacheKey] = future;
    _cache[placeName] = future;
    
    return future;
  }

  static Future<String> _fetchWithTimeout(
    String placeName,
    double? lat,
    double? lon,
  ) async {
    try {
      return await _fetch(placeName, lat: lat, lon: lon)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('PlaceImageService: timeout for "$placeName"');
        return '';
      });
    } catch (e) {
      debugPrint('PlaceImageService: error for "$placeName": $e');
      return '';
    }
  }

  static Future<String> _fetch(
    String placeName, {
    double? lat,
    double? lon,
  }) async {
    // Run searches in parallel to save time, but we will evaluate them in strict priority
    final futures = <Future<String>>[
      _titleSearch(placeName),
      _textSearch(placeName),
    ];
    
    // Add geo search if coordinates exist, but with a TIGHT radius (500m).
    // Previously, 5000m caused nearby palaces to hijack the image of hills/restaurants!
    if (lat != null && lon != null) {
      futures.add(_geoSearch(lat, lon, radius: 500));
    }

    final results = await Future.wait(futures);
    
    // Priority 1: Exact Title Match (Highest Accuracy)
    if (results[0].isNotEmpty) return results[0];
    
    // Priority 2: Text Search Match (Handles commas/short names accurately)
    if (results[1].isNotEmpty) return results[1];
    
    // Priority 3: Geo Search (Only as a last resort, within 500m)
    if (futures.length > 2 && results[2].isNotEmpty) return results[2];

    return '';
  }

  static Future<String> _geoSearch(double lat, double lon, {int radius = 500}) async {
    try {
      final uri = Uri.parse(
        'https://en.wikipedia.org/w/api.php'
        '?action=query'
        '&generator=geosearch'
        '&ggscoord=$lat|$lon'
        '&ggsradius=$radius'
        '&ggslimit=5'
        '&prop=pageimages'
        '&pithumbsize=640'
        '&format=json'
        '&origin=*',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'RoUniityApp/1.0'})
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final pages =
            jsonDecode(res.body)['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null) {
          for (final page in pages.values) {
            final thumb = page['thumbnail']?['source'] as String?;
            if (thumb != null && thumb.isNotEmpty) return thumb;
          }
        }
      }
    } catch (e) {
      debugPrint('PlaceImageService: geoSearch error: $e');
    }
    return '';
  }

  static Future<String> _titleSearch(String placeName) async {
    try {
      final uri = Uri.parse(
        'https://en.wikipedia.org/w/api.php'
        '?action=query'
        '&titles=${Uri.encodeComponent(placeName)}'
        '&prop=pageimages'
        '&pithumbsize=640'
        '&format=json'
        '&origin=*',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'RoUniityApp/1.0'})
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final pages =
            jsonDecode(res.body)['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null) {
          for (final page in pages.values) {
            final thumb = page['thumbnail']?['source'] as String?;
            if (thumb != null && thumb.isNotEmpty) return thumb;
          }
        }
      }
    } catch (e) {
      debugPrint('PlaceImageService: titleSearch error: $e');
    }
    return '';
  }

  static Future<String> _textSearch(String placeName) async {
    String result = await _performTextSearch(placeName);
    
    // If no result and it's a long address (e.g. "Name, Street, City"), 
    // try searching just the first part (the actual place name)
    if (result.isEmpty && placeName.contains(',')) {
      final shortName = placeName.split(',').first.trim();
      if (shortName.isNotEmpty && shortName != placeName) {
        result = await _performTextSearch(shortName);
      }
    }
    return result;
  }

  static Future<String> _performTextSearch(String query) async {
    try {
      final searchUri = Uri.parse(
        'https://en.wikipedia.org/w/api.php'
        '?action=query'
        '&list=search'
        '&srsearch=${Uri.encodeComponent(query)}'
        '&srlimit=3'
        '&format=json'
        '&origin=*',
      );
      final searchRes =
          await http.get(searchUri, headers: {'User-Agent': 'RoUniityApp/1.0'})
              .timeout(const Duration(seconds: 4));
      if (searchRes.statusCode == 200) {
        final hits = (jsonDecode(searchRes.body)['query']?['search']
                as List<dynamic>?) ??
            [];
        for (final hit in hits) {
          final pageId = hit['pageid'];
          if (pageId == null) continue;
          final detailUri = Uri.parse(
            'https://en.wikipedia.org/w/api.php'
            '?action=query'
            '&pageids=$pageId'
            '&prop=pageimages'
            '&pithumbsize=640'
            '&format=json'
            '&origin=*',
          );
          final detailRes = await http
              .get(detailUri, headers: {'User-Agent': 'RoUniityApp/1.0'})
              .timeout(const Duration(seconds: 4));
          if (detailRes.statusCode == 200) {
            final pages = jsonDecode(detailRes.body)['query']?['pages']
                as Map<String, dynamic>?;
            if (pages != null) {
              final thumb =
                  pages.values.first['thumbnail']?['source'] as String?;
              if (thumb != null && thumb.isNotEmpty) return thumb;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('PlaceImageService: textSearch error for "$query": $e');
    }
    return '';
  }

  static void clearCache() => _cache.clear();
}
