import 'package:http/http.dart' as http;

import '../plan/pilgrimage_models.dart';
import 'anitabi_image_url.dart';
import 'anitabi_service_config.dart';
import 'image_bytes.dart';
import 'bounded_image_decoder.dart';

typedef AnitabiImageHttpGetter =
    Future<http.Response> Function(Uri uri, {Duration? timeout});

Future<List<int>?> fetchAnitabiImageBytes(
  String url, {
  AnitabiImageSource source = AnitabiImageSource.auto,
  AnitabiImageHttpGetter? get,
  AnitabiServiceConfig? serviceConfig,
  Duration timeout = const Duration(seconds: 12),
  int? maxBytes,
  http.Client? client,
}) async {
  if (get != null && (maxBytes != null || client != null)) {
    throw ArgumentError(
      'Buffered get cannot be combined with bounded/client reads',
    );
  }
  if (maxBytes != null && maxBytes <= 0) {
    throw ArgumentError.value(maxBytes, 'maxBytes');
  }
  final candidates = candidateAnitabiImageUrls(
    url,
    source: source,
    serviceConfig: serviceConfig,
  );
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
      if (maxBytes != null || client != null) {
        final ownedClient = client ?? http.Client();
        try {
          final response = await ownedClient
              .send(http.Request('GET', uri))
              .timeout(timeout);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            await response.stream.listen(null).cancel();
            continue;
          }
          final bytes = await readImageStreamBounded(
            response.stream.timeout(timeout),
            maxBytes: maxBytes ?? maxImageEncodedBytes,
            declaredLength: response.contentLength,
          );
          if (isSupportedImageBytes(bytes) ||
              (bytes.length >= 6 &&
                  String.fromCharCodes(bytes.take(6)).startsWith('GIF8')) ||
              (bytes.length >= 12 &&
                  String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp')) {
            return bytes;
          }
          continue;
        } finally {
          if (client == null) ownedClient.close();
        }
      }
      final response = await httpGet(uri, timeout: timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        continue;
      }
      if (!isSupportedImageBytes(response.bodyBytes)) {
        continue;
      }
      return response.bodyBytes;
    } on ImageBudgetException {
      rethrow;
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
