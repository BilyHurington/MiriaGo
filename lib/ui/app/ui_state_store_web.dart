import 'package:web/web.dart' as web;

Future<String?> readUiState(String key) async {
  try {
    return web.window.localStorage.getItem('miriago.$key');
  } catch (_) {
    return null;
  }
}

Future<void> writeUiState(String key, String value) async {
  try {
    web.window.localStorage.setItem('miriago.$key', value);
  } catch (_) {}
}
