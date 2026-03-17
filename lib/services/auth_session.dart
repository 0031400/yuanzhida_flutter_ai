import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  AuthSession._();

  static const _usernameKey = 'answerly.username';
  static const _tokenKey = 'answerly.token';

  static String? _username;
  static String? _token;

  static String? get username => _username;
  static String? get token => _token;

  static bool get isLoggedIn =>
      (_username != null && _username!.isNotEmpty) &&
      (_token != null && _token!.isNotEmpty);

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_usernameKey);
    final token = prefs.getString(_tokenKey);
    if (username == null || username.isEmpty || token == null || token.isEmpty) {
      await clear();
      return;
    }

    _username = username;
    _token = token;
  }

  static Future<void> save({
    required String username,
    required String token,
  }) async {
    _username = username;
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clear() async {
    _username = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_tokenKey);
  }
}
