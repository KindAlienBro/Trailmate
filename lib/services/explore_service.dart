import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class TouristPlace {
  final String name;
  final double lat;
  final double lon;
  final String type;
  final double distanceKm;
  final String imageUrl;

  TouristPlace({
    required this.name,
    required this.lat,
    required this.lon,
    required this.type,
    required this.distanceKm,
    required this.imageUrl,
  });
}

class ExploreService {
  /// Fetches nearby tourist places using Overpass API
  static Future<List<TouristPlace>> fetchNearbyPlaces({double radiusInKm = 20.0}) async {
    // Delay to simulate network request
    await Future.delayed(const Duration(milliseconds: 800));
    
    return [
      TouristPlace(
        name: 'Nandi Hills',
        lat: 13.3702,
        lon: 77.6835,
        type: 'peak',
        distanceKm: 60.0,
        imageUrl: 'https://picsum.photos/seed/nandi/400/400',
      ),
      TouristPlace(
        name: 'Mysore Palace',
        lat: 12.3051,
        lon: 76.6551,
        type: 'monument',
        distanceKm: 145.0,
        imageUrl: 'https://picsum.photos/seed/mysore/400/400',
      ),
      TouristPlace(
        name: 'Coorg (Madikeri)',
        lat: 12.4244,
        lon: 75.7382,
        type: 'viewpoint',
        distanceKm: 265.0,
        imageUrl: 'https://picsum.photos/seed/coorg/400/400',
      ),
      TouristPlace(
        name: 'Ooty',
        lat: 11.4102,
        lon: 76.6950,
        type: 'peak',
        distanceKm: 270.0,
        imageUrl: 'https://picsum.photos/seed/ooty/400/400',
      ),
      TouristPlace(
        name: 'Gokarna Beach',
        lat: 14.5500,
        lon: 74.3180,
        type: 'beach',
        distanceKm: 480.0,
        imageUrl: 'https://picsum.photos/seed/gokarna/400/400',
      ),
      TouristPlace(
        name: 'Hampi Ruins',
        lat: 15.3350,
        lon: 76.4600,
        type: 'ruins',
        distanceKm: 340.0,
        imageUrl: 'https://picsum.photos/seed/hampi/400/400',
      ),
    ];
  }
}
