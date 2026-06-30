import 'package:http/http.dart' as http;

import '../plan/pilgrimage_models.dart';
import 'anitabi_image_url.dart';
import 'image_bytes.dart';

typedef AnitabiImageHttpGetter =
    Future<http.Response> Function(Uri uri, {Duration? timeout});

Future<List<int>?> fetchAnitabiImageBytes(
  String url, {
  AnitabiImageSource source = AnitabiImageSource.auto,
  AnitabiImageHttpGetter? get,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final candidates = candidateAnitabiImageUrls(url, source: source);
  if (candidates.isEmpty) {
    return null;
  }
  final httpGet = get ?? _defaultHttpGet;
  for (final candidate in candidates) {
    final uri = Uri.tryParse(candidate);
    if (uri == null) {
      continue;
    }
    try {
      final response = await httpGet(uri, timeout: timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        continue;
      }
      if (!isSupportedImageBytes(response.bodyBytes)) {
        continue;
      }
      return response.bodyBytes;
    } catch (_) {
      continue;
    }
  }
  return null;
}

Future<http.Response> _defaultHttpGet(Uri uri, {Duration? timeout}) {
  final request = http.get(uri);
  return timeout == null ? request : request.timeout(timeout);
}
