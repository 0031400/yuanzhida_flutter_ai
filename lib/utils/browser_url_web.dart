import 'package:web/web.dart' as web;

void replaceBrowserPath(String path) {
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  final location = web.window.location;
  final currentHash = location.hash;

  if (currentHash.startsWith('#/')) {
    final basePath = location.pathname;
    final search = location.search;
    web.window.history.replaceState(
      null,
      '',
      '$basePath$search#$normalizedPath',
    );
    return;
  }

  web.window.history.replaceState(null, '', normalizedPath);
}
