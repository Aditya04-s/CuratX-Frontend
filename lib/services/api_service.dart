import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

typedef JsonMap = Map<String, dynamic>;

class ApiService {
  static Map<String, String> _headersWithUser(String userId) => {
        ...ApiConfig.headers,
        'x-user-id': userId,
      };

  static dynamic _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw Exception(
        'Server returned non-JSON (${response.statusCode}). Check ApiConfig.baseUrl.',
      );
    }
  }

  static String _extractError(dynamic decoded, http.Response response) {
    if (decoded is JsonMap) {
      return (decoded['detail'] ?? decoded['message'] ?? response.body)
          .toString();
    }
    return response.body;
  }

  static Future<JsonMap> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/signup');
    var response = await http
        .post(
          uri,
          headers: ApiConfig.headers,
          body: jsonEncode({
            'name': name.trim(),
            'email': email.trim(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 404) {
      uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/register');
      response = await http
          .post(
            uri,
            headers: ApiConfig.headers,
            body: jsonEncode({
              'username': name.trim(),
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));
    }

    final decoded = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractError(decoded, response));
    }

    final map = JsonMap.from(decoded as Map);
    map['user_id'] ??= 'local_${email.trim().hashCode}';
    map['name'] ??= name.trim();
    map['email'] ??= email.trim();
    map['has_onboarded'] ??= false;
    return map;
  }

  static Future<JsonMap> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/login');
    final response = await http
        .post(
          uri,
          headers: ApiConfig.headers,
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractError(decoded, response));
    }

    final map = JsonMap.from(decoded as Map);
    map['user_id'] ??= '12345';
    map['name'] ??= email.trim().split('@').first;
    map['email'] ??= email.trim();
    map['has_onboarded'] ??= false;
    return map;
  }

  static Future<JsonMap> uploadResume({
    required String userId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          ...ApiConfig.multipartHeaders,
          'x-user-id': userId,
        },
        validateStatus: (_) => true,
      ),
    );

    FormData buildForm() => FormData.fromMap({
          'file': MultipartFile.fromBytes(
            fileBytes,
            filename: fileName,
            contentType: DioMediaType('application', 'pdf'),
          ),
        });

    var res = await dio.post(
      '${ApiConfig.baseUrl}/api/users/$userId/upload-resume',
      data: buildForm(),
    );

    if (res.statusCode == 404) {
      res = await dio.post(
        '${ApiConfig.baseUrl}/api/resumes/upload',
        data: buildForm(),
      );
    }

    final code = res.statusCode ?? 500;
    if (code < 200 || code >= 300) {
      final data = res.data;
      final detail =
          data is Map ? (data['detail'] ?? data['message'] ?? data) : data;
      throw Exception('Resume upload failed ($code): $detail');
    }

    return res.data is Map
        ? JsonMap.from(res.data as Map)
        : {'status': 'success'};
  }

  static Future<JsonMap> submitQuestionnaire({
    required String userId,
    required List<dynamic> answers,
    required List<String> extractedInterests,
  }) async {
    final headers = _headersWithUser(userId);
    var uri = Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/questionnaire');
    var response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'answers': answers,
            'extracted_interests': extractedInterests,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 404) {
      uri = Uri.parse('${ApiConfig.baseUrl}/api/profile/questionnaire');
      response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'selected_topics': extractedInterests,
            }),
          )
          .timeout(const Duration(seconds: 30));
    }

    final decoded = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractError(decoded, response));
    }
    return JsonMap.from(decoded as Map);
  }

  static Future<JsonMap> fetchUserFeed({
    required String userId,
    bool forceRefresh = false,
  }) async {
    final headers = _headersWithUser(userId);
    var uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/users/$userId/feed',
    ).replace(
      queryParameters: forceRefresh ? {'force_refresh': 'true'} : null,
    );

    var response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 90));

    if (response.statusCode == 404) {
      uri = Uri.parse('${ApiConfig.baseUrl}/api/feed');
      response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 90));
    }

    final decoded = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractError(decoded, response));
    }
    if (decoded is! JsonMap) {
      throw Exception('Invalid feed response format.');
    }

    if (decoded['articles'] == null &&
        (decoded['featured'] is List || decoded['standard'] is List)) {
      final merged = <JsonMap>[];
      for (final key in ['featured', 'standard']) {
        final list = decoded[key];
        if (list is List) {
          for (final item in list) {
            if (item is Map) {
              final art = JsonMap.from(item);
              art['summary'] ??= art['ai_summary'] ?? art['description'] ?? '';
              merged.add(art);
            }
          }
        }
      }
      return {
        'status': 'completed',
        'articles': merged,
      };
    }

    return decoded;
  }

  static Future<void> logInteraction({
    required String userId,
    required String actionType,
    required List<String> interestTokens,
    required String articleUrl,
    required String articleTitle,
    required List<String> matchedTags,
    int durationSeconds = 5,
  }) async {
    final headers = _headersWithUser(userId);
    var uri = Uri.parse('${ApiConfig.baseUrl}/api/interactions');
    var response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
            'interaction_type': actionType,
            'interest_tokens': interestTokens,
            'article_url': articleUrl,
            'article_title': articleTitle,
            'matched_tags': matchedTags,
            'duration_seconds': durationSeconds,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 404) {
      uri = Uri.parse('${ApiConfig.baseUrl}/api/interactions/log');
      response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'user_id': userId,
              'article_url': articleUrl,
              'article_title': articleTitle,
              'matched_tags': matchedTags,
              'interaction_type': actionType,
              'duration_seconds': durationSeconds,
            }),
          )
          .timeout(const Duration(seconds: 15));
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Interaction failed (${response.statusCode}): ${response.body}',
      );
    }
    debugPrint('CuratX interaction logged: $actionType -> $articleTitle');
  }
}