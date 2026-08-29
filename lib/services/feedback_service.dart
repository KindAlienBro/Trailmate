import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class FeedbackService {
  static Future<void> submitFeedback({
    required String userId,
    required String userName,
    required int rating,
    required String message,
    required String suggestions,
  }) async {
    try {
      final url = Uri.parse('${AppConstants.serverBaseUrl}/api/feedback');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'userName': userName,
          'rating': rating,
          'message': message,
          'suggestions': suggestions,
          'platform': 'android',
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }
}

