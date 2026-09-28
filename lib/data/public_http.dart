import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'anitabi_service_config.dart';

/// Sends a GET that follows redirects itself, refusing any hop that leaves
/// public hosts, so a public address cannot bounce a request into the local
/// network. [allowHttp] permits plain HTTP hops (for images from plan data).
///
/// Browsers follow redirects themselves (a disabled redirect is an error
/// there); only the first hop is ours to check on the web.
Future<http.StreamedResponse> sendPublicGet(
  http.Client client,
  Uri uri, {
  bool allowHttp = false,
  int maxRedirects = 5,
  Map<String, String>? headers,
}) async {
  var current = uri;
  for (var redirects = 0; ; redirects++) {
    if (!isPublicWebUri(current, allowHttp: allowHttp)) {
      throw http.ClientException('Refusing a non-public address', current);
    }
    final request = http.Request('GET', current)..followRedirects = kIsWeb;
    if (headers != null) {
      request.headers.addAll(headers);
    }
    final response = await client.send(request);
    final location = response.headers['location'];
    if (!_redirectStatuses.contains(response.statusCode) || location == null) {
      return response;
    }
    await response.stream.listen(null).cancel();
    if (redirects >= maxRedirects) {
      throw http.ClientException('Too many redirects', current);
    }
    try {
      current = current.resolve(location);
    } on FormatException catch (error) {
      throw http.ClientException('Invalid redirect: ${error.message}', current);
    }
  }
}

/// [sendPublicGet] with the body read into memory.
Future<http.Response> getPublic(
  http.Client client,
  Uri uri, {
  bool allowHttp = false,
  Map<String, String>? headers,
}) async => http.Response.fromStream(
  await sendPublicGet(client, uri, allowHttp: allowHttp, headers: headers),
);

/// Lets tests serve images from a local test server.
@visibleForTesting
var allowLocalNetworkHostsForTesting = false;

bool isPublicWebUri(Uri uri, {bool allowHttp = false}) =>
    (uri.scheme == 'https' || (allowHttp && uri.scheme == 'http')) &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty &&
    (allowLocalNetworkHostsForTesting || !isLocalOrPrivateHost(uri.host));

const _redirectStatuses = {301, 302, 303, 307, 308};
