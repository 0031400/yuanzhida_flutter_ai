import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'http_client_stub.dart'
    if (dart.library.js_interop) 'http_client_web.dart';

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
  final http.Client _client = createHttpClient();

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

  Future<void> sendRegisterCode({required String mail}) async {
    final uri = Uri.parse(
      '$baseUrl/api/answerly/v1/user/send-code',
    ).replace(queryParameters: {'mail': mail});
    final response = await _client.get(uri);

    _ensureSuccessStatus(response, fallbackMessage: 'Send register code failed');
    _ensureSuccessBody(response.body);
  }

  Future<void> register({
    required String username,
    required String password,
    required String mail,
    required String code,
  }) async {
    final uri = Uri.parse('$baseUrl/api/answerly/v1/user');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'mail': mail,
        'code': code,
      }),
    );

    _ensureSuccessStatus(response, fallbackMessage: 'Register request failed');
    _ensureSuccessBody(response.body);
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

    _ensureSuccessStatus(response, fallbackMessage: 'Login request failed');

    final body = _ensureSuccessBody(response.body);

    final data = body['data'] as Map<String, dynamic>?;
    final token = data?['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('A000000', 'Token missing in response');
    }

    return token;
  }

  void _ensureSuccessStatus(
    http.Response response, {
    required String fallbackMessage,
  }) {
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode.toString(),
        fallbackMessage,
      );
    }
  }

  Map<String, dynamic> _ensureSuccessBody(String bodyText) {
    final body = jsonDecode(bodyText) as Map<String, dynamic>;
    final codeValue = body['code']?.toString() ?? 'unknown';
    if (codeValue != '0') {
      throw ApiException(codeValue, body['message']?.toString());
    }
    return body;
  }
}
