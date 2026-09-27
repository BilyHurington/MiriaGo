import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<File> _file() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}${Platform.pathSeparator}ui_state.json');
}

Future<Map<String, dynamic>> _read() async {
  try {
    final file = await _file();
    if (!await file.exists()) return {};
    final decoded = jsonDecode(await file.readAsString());
    return decoded is Map<String, dynamic> ? decoded : {};
  } catch (_) {
    return {};
  }
}

Future<String?> readUiState(String key) async {
  final value = (await _read())[key];
  return value is String ? value : null;
}

Future<void> writeUiState(String key, String value) async {
  try {
    final data = await _read();
    data[key] = value;
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data), flush: true);
  } catch (_) {}
}
