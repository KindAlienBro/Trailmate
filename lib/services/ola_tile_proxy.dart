import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class OlaTileProxy {
  static HttpServer? _server;
  static int _port = 0;

  static Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    _server!.listen(_handleRequest);
  }

  static String get proxyStyleUrl {
    return 'http://127.0.0.1:$_port/tiles/vector/v1/styles/default-light-full/style.json';
  }

  static Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      final targetUrl = 'https://api.olamaps.io$path';
      
      final proxyResponse = await http.get(
        Uri.parse(targetUrl),
        headers: {
          'X-Api-Key': AppConstants.olaApiKey,
        },
      );

      request.response.statusCode = proxyResponse.statusCode;
      proxyResponse.headers.forEach((key, value) {
        final lowerKey = key.toLowerCase();
        if (lowerKey != 'content-length' && 
            lowerKey != 'transfer-encoding' && 
            lowerKey != 'content-encoding') {
          request.response.headers.set(key, value);
        }
      });

      if (path.endsWith('.json') || (proxyResponse.headers['content-type']?.contains('json') == true)) {
        String body = proxyResponse.body;
        body = body.replaceAll('https://api.olamaps.io', 'http://127.0.0.1:$_port');
        final bytes = utf8.encode(body);
        request.response.add(bytes);
      } else {
        request.response.add(proxyResponse.bodyBytes);
      }
      
      await request.response.close();
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }
}
