import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/wanikani/wanikani_api_client.dart';
import 'package:hajiku/src/core/wanikani/wanikani_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('returns the parsed user on a 200 response', () async {
    final mockClient = MockClient((request) async {
      expect(request.url, Uri.parse('https://api.wanikani.com/v2/user'));
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['Wanikani-Revision'], '20170710');

      return http.Response(
        jsonEncode({
          'object': 'user',
          'data': {'username': 'taro', 'level': 5},
        }),
        200,
      );
    });

    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: mockClient,
    );

    final user = await client.getUser();

    expect(user.username, 'taro');
    expect(user.level, 5);
  });

  test('throws WaniKaniAuthException when no token is configured', () async {
    final client = WaniKaniApiClient(
      tokenProvider: () async => null,
      httpClient: MockClient((request) async => http.Response('', 200)),
    );

    await expectLater(client.getUser(), throwsA(isA<WaniKaniAuthException>()));
  });

  test('throws WaniKaniAuthException on a 401 response', () async {
    final client = WaniKaniApiClient(
      tokenProvider: () async => 'bad-token',
      httpClient: MockClient((request) async => http.Response('', 401)),
    );

    await expectLater(client.getUser(), throwsA(isA<WaniKaniAuthException>()));
  });

  test('throws WaniKaniApiException on an unexpected status', () async {
    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async => http.Response('', 500)),
    );

    await expectLater(
      client.getUser(),
      throwsA(
        isA<WaniKaniApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
  });
}
