import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // For Flutter Web running on the same computer as FastAPI.
  // For a physical phone, replace this with your computer's LAN IP.
  static const String baseUrl = 'http://127.0.0.1:8000';

  // Development/test account currently used in MongoDB Atlas.
  static const String testUserId = '6a719ad48a4d6fd83660172c';

  static Future<Map<String, dynamic>> fetchUserFeed({
    bool forceRefresh = false,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/users/$testUserId/feed',
    ).replace(
      queryParameters: forceRefresh ? {'force_refresh': 'true'} : null,
    );

    debugPrint('Fetching CuratX live feed: $uri');

    final response = await http
        .get(
          uri,
          headers: const {
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 45));

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw Exception(
        'Backend returned a non-JSON response (${response.statusCode}).',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail'] ?? response.body
          : response.body;
      throw Exception(
        'Feed request failed (${response.statusCode}): $detail',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid feed response format from backend.');
    }

    debugPrint(
      'CuratX feed status: ${decoded['status']}, '
      'source: ${decoded['source'] ?? 'unknown'}',
    );

    return decoded;
  }

  // Kept for the existing resume screen, which prefetches the feed on launch.
  // The actual article list is loaded by NewsFeedScreen.
  static Future<void> fetchHomeFeed() async {
    try {
      await fetchUserFeed();
    } catch (error) {
      debugPrint('CuratX feed prefetch error: $error');
    }
  }

  static Future<void> logInteraction({
    required String actionType,
    required List<String> matchedTags,
  }) async {
    final uri = Uri.parse('$baseUrl/api/interactions');

    final response = await http
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'user_id': testUserId,
            'interaction_type': actionType,
            'interest_tokens': matchedTags,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Interaction request failed '
        '(${response.statusCode}): ${response.body}',
      );
    }

    debugPrint('CuratX interaction saved successfully!');
    debugPrint(response.body);
  }
}
