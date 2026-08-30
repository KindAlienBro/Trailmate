import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WikipediaService {
  static final Map<String, Future<String>> _cache = {};

  static Future<String> fetchDescription(String placeName) {
    if (_cache.containsKey(placeName)) {
      return _cache[placeName]!;
    }

    final future = _fetchWithTimeout(placeName).then((result) {
      if (result.isEmpty || result == 'Description not available.') {
        _cache.remove(placeName);
      }
      return result;
    });

    _cache[placeName] = future;
    return future;
  }

  static Future<String> _fetchWithTimeout(String placeName) async {
    try {
      return await _fetch(placeName)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('WikipediaService: timeout for "$placeName"');
        return 'Description not available.';
      });
    } catch (e) {
      debugPrint('WikipediaService: error for "$placeName": $e');
      return 'Description not available.';
    }
  }

  static Future<String> _fetch(String placeName) async {
    try {
      // 1. First try an exact title match
      var uri = Uri.parse(
        'https://en.wikipedia.org/w/api.php'
        '?action=query'
        '&prop=extracts'
        '&exintro=1'
        '&explaintext=1'
        '&titles=${Uri.encodeComponent(placeName)}'
        '&format=json'
        '&origin=*',
      );

      var res = await http.get(uri, headers: {'User-Agent': 'RoUniityApp/1.0'});
      if (res.statusCode == 200) {
        final pages = jsonDecode(res.body)['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && !pages.containsKey('-1')) {
          final extract = pages.values.first['extract'] as String?;
          if (extract != null && extract.trim().isNotEmpty) {
            return _cleanExtract(extract);
          }
        }
      }

      // 2. If exact match fails, try a text search to find the closest article
      final searchUri = Uri.parse(
        'https://en.wikipedia.org/w/api.php'
        '?action=query'
        '&list=search'
        '&srsearch=${Uri.encodeComponent(placeName)}'
        '&srlimit=1'
        '&format=json'
        '&origin=*',
      );
      
      final searchRes = await http.get(searchUri, headers: {'User-Agent': 'RoUniityApp/1.0'});
      if (searchRes.statusCode == 200) {
        final hits = jsonDecode(searchRes.body)['query']?['search'] as List<dynamic>?;
        if (hits != null && hits.isNotEmpty) {
          final pageId = hits.first['pageid'];
          if (pageId != null) {
            final detailUri = Uri.parse(
              'https://en.wikipedia.org/w/api.php'
              '?action=query'
              '&prop=extracts'
              '&exintro=1'
              '&explaintext=1'
              '&pageids=$pageId'
              '&format=json'
              '&origin=*',
            );
            final detailRes = await http.get(detailUri, headers: {'User-Agent': 'RoUniityApp/1.0'});
            if (detailRes.statusCode == 200) {
              final dPages = jsonDecode(detailRes.body)['query']?['pages'] as Map<String, dynamic>?;
              if (dPages != null) {
                final extract = dPages.values.first['extract'] as String?;
                if (extract != null && extract.trim().isNotEmpty) {
                  return _cleanExtract(extract);
                }
              }
            }
          }
        }
      }

    } catch (e) {
      debugPrint('WikipediaService error: $e');
    }
    return 'Description not available. This place might not have a Wikipedia article yet.';
  }

  static String _cleanExtract(String extract) {
    // Remove " (listen)" or weird pronunciation guides often found in Wikipedia intros
    var cleaned = extract.replaceAll(RegExp(r' \([^\)]*\)'), '');
    // Replace multiple newlines with double newline for clean paragraph spacing
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }
}
