import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/wanikani_user.dart';
import 'wanikani_exception.dart';

/// Thin client for the WaniKani API v2 (https://docs.api.wanikani.com).
class WaniKaniApiClient {
  WaniKaniApiClient({required this._tokenProvider, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static final Uri _baseUrl = Uri.parse('https://api.wanikani.com/v2/');
  static const _apiRevision = '20170710';

  final Future<String?> Function() _tokenProvider;
  final http.Client _httpClient;

  /// Fetches the authenticated user's profile, validating the API token.
  Future<WaniKaniUser> getUser() async {
    final json = await _get('user');
    return WaniKaniUser.fromJson(json);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const WaniKaniAuthException('No WaniKani API token configured.');
    }

    final response = await _httpClient.get(
      _baseUrl.resolve(path),
      headers: {
        'Authorization': 'Bearer $token',
        'Wanikani-Revision': _apiRevision,
      },
    );

    switch (response.statusCode) {
      case 200:
        return jsonDecode(response.body) as Map<String, dynamic>;
      case 401:
        throw const WaniKaniAuthException('WaniKani API token was rejected.');
      default:
        throw WaniKaniApiException(
          response.statusCode,
          'WaniKani API request to "$path" failed with status '
          '${response.statusCode}.',
        );
    }
  }
}
