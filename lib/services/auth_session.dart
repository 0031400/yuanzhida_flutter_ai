class AuthSession {
  AuthSession._();

  static String? _username;
  static String? _token;

  static String? get username => _username;
  static String? get token => _token;

  static bool get isLoggedIn =>
      (_username != null && _username!.isNotEmpty) &&
      (_token != null && _token!.isNotEmpty);

  static void save({
    required String username,
    required String token,
  }) {
    _username = username;
    _token = token;
  }

  static void clear() {
    _username = null;
    _token = null;
  }
}
