import 'dart:convert';
import 'dart:typed_data';

import 'package:http/browser_client.dart' as http;

class ApiException implements Exception {
  ApiException(this.code, this.message);
  final String code;
  final String? message;

  @override
  String toString() => 'ApiException(code: $code, message: $message)';
}

class AnswerlyApi {
  AnswerlyApi({required this.baseUrl});

  final String baseUrl;
  final _client = http.BrowserClient()..withCredentials = true;

  Future<Uint8List> fetchCaptcha() async {
    final uri = Uri.parse('$baseUrl/api/answerly/v1/user/captcha');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode.toString(),
        'Captcha request failed',
      );
    }

    return response.bodyBytes;
  }

  Future<String> login({
    required String username,
    required String password,
    required String code,
  }) async {
    final uri = Uri.parse('$baseUrl/api/answerly/v1/user/login');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'code': code,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode.toString(),
        'Login request failed',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final codeValue = body['code']?.toString() ?? 'unknown';
    if (codeValue != '0') {
      throw ApiException(codeValue, body['message']?.toString());
    }

    final data = body['data'] as Map<String, dynamic>?;
    final token = data?['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('A000000', 'Token missing in response');
    }

    return token;
  }
}
