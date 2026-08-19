import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'Txtd52X2o49O1UlPk7euny0DUhjd65VGQaMWzBoR';
  final geoRes = await http.get(Uri.parse('https://api.olamaps.io/places/v1/reverse-geocode?latlng=13.0845,77.4865&api_key=$apiKey'));
  print('Reverse Geo: ${geoRes.body}');
}
