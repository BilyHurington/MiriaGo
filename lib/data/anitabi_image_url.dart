import '../plan/pilgrimage_models.dart';

const anitabiOfficialImageHost = 'image.anitabi.cn';
const anitabiMirrorImageHost = 'img-tc.anitabi.cn';

const anitabiImageHosts = {anitabiOfficialImageHost, anitabiMirrorImageHost};

String? anitabiFullResolutionImageUrl(String? url) {
  if (url == null || url.isEmpty) {
    return url;
  }

  final uri = Uri.tryParse(url);
  if (uri == null || !anitabiImageHosts.contains(uri.host)) {
    return url;
  }

  final queryParameters = Map<String, String>.from(uri.queryParameters)
    ..remove('plan');

  final fullUrl = uri.replace(queryParameters: queryParameters).toString();
  return fullUrl.endsWith('?')
      ? fullUrl.substring(0, fullUrl.length - 1)
      : fullUrl;
}

String? anitabiThumbnailImageUrl(String? url) {
  final fullUrl = anitabiFullResolutionImageUrl(url);
  if (fullUrl == null || fullUrl.isEmpty) {
    return fullUrl;
  }

  final uri = Uri.tryParse(fullUrl);
  if (uri == null || !anitabiImageHosts.contains(uri.host)) {
    return fullUrl;
  }

  return uri
      .replace(queryParameters: {...uri.queryParameters, 'plan': 'h160'})
      .toString();
}

String? canonicalAnitabiImageUrl(String? url) {
  if (url == null || url.isEmpty) {
    return url;
  }

  final uri = Uri.tryParse(url);
  if (uri == null || !anitabiImageHosts.contains(uri.host)) {
    return url;
  }
  return uri.replace(host: anitabiOfficialImageHost).toString();
}

String? resolveAnitabiImageUrl(
  String? url, {
  AnitabiImageSource source = AnitabiImageSource.auto,
}) {
  if (url == null || url.isEmpty) {
    return url;
  }

  final uri = Uri.tryParse(url);
  if (uri == null || !anitabiImageHosts.contains(uri.host)) {
    return url;
  }

  final host = switch (source) {
    AnitabiImageSource.mirror => anitabiMirrorImageHost,
    _ => anitabiOfficialImageHost,
  };
  return uri.replace(host: host).toString();
}

List<String> candidateAnitabiImageUrls(
  String? url, {
  AnitabiImageSource source = AnitabiImageSource.auto,
}) {
  if (url == null || url.isEmpty) {
    return const [];
  }

  final resolved = resolveAnitabiImageUrl(url, source: source);
  if (resolved == null || resolved.isEmpty) {
    return const [];
  }

  final uri = Uri.tryParse(resolved);
  if (uri == null || !anitabiImageHosts.contains(uri.host)) {
    return [resolved];
  }

  return switch (source) {
    AnitabiImageSource.official => [
      uri.replace(host: anitabiOfficialImageHost).toString(),
    ],
    AnitabiImageSource.mirror => [
      uri.replace(host: anitabiMirrorImageHost).toString(),
    ],
    AnitabiImageSource.auto => [
      uri.replace(host: anitabiOfficialImageHost).toString(),
      uri.replace(host: anitabiMirrorImageHost).toString(),
    ],
  };
}
