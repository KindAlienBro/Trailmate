import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'Txtd52X2o49O1UlPk7euny0DUhjd65VGQaMWzBoR';
  final origin = '12.9715987,77.5945627'; // Bangalore
  final dest = '15.2993,74.1240'; // Goa

  final uri = Uri.parse('https://api.olamaps.io/routing/v1/directions').replace(queryParameters: {
    'origin': origin,
    'destination': dest,
    'api_key': apiKey,
    'mode': 'driving'
  });

  final dirRes = await http.post(uri);
  
  if (dirRes.statusCode == 200) {
    final data = jsonDecode(dirRes.body);
    final routes = data['routes'];
    if (routes != null && routes.isNotEmpty) {
      final leg = routes[0]['legs'][0];
      print('Distance (exact coordinates): ${leg['distance']}');
      print('Duration: ${leg['duration']}');
      
      // Look at the readable distance/duration
      if (leg.containsKey('readable_distance')) {
        print('Readable Distance: ${leg['readable_distance']}');
      }
    }
  } else {
    print('Dir Error: ${dirRes.body}');
  }
}
