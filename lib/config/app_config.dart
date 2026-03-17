class AppConfig {
  AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'ANSWERLY_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const cosBaseUrl = String.fromEnvironment(
    'ANSWERLY_COS_BASE_URL',
    defaultValue:
        'https://yuanzhida-cos-1352975306.cos.ap-beijing.myqcloud.com',
  );

  static String resolveMediaUrl(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.hasScheme) {
      return normalized;
    }
    return '${cosBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/'
        '${normalized.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
