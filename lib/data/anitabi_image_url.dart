import '../plan/pilgrimage_models.dart';
import 'anitabi_service_config.dart';

const anitabiOfficialImageHost = 'image.anitabi.cn';
const anitabiMirrorImageHost = 'img-tc.anitabi.cn';

const anitabiImageHosts = {anitabiOfficialImageHost, anitabiMirrorImageHost};

String? anitabiFullResolutionImageUrl(
  String? url, {
  AnitabiServiceConfig? serviceConfig,
}) {
  if (url == null || url.isEmpty) {
    return url;
  }

  final uri = Uri.tryParse(url);
  final config = serviceConfig ?? AnitabiServiceConfig.current;
  if (uri == null || _knownImageRelativePath(uri, config) == null) {
    return url;
  }

  final queryParameters = Map<String, String>.from(uri.queryParameters)
    ..remove('plan');

  final fullUrl = uri.replace(queryParameters: queryParameters).toString();
  return fullUrl.endsWith('?')
      ? fullUrl.substring(0, fullUrl.length - 1)
      : fullUrl;
}

String? anitabiThumbnailImageUrl(
  String? url, {
  AnitabiServiceConfig? serviceConfig,
}) {
  final config = serviceConfig ?? AnitabiServiceConfig.current;
  final fullUrl = anitabiFullResolutionImageUrl(url, serviceConfig: config);
  if (fullUrl == null || fullUrl.isEmpty) {
    return fullUrl;
  }

  final uri = Uri.tryParse(fullUrl);
  if (uri == null || _knownImageRelativePath(uri, config) == null) {
    return fullUrl;
  }

  return uri
      .replace(queryParameters: {...uri.queryParameters, 'plan': 'h160'})
      .toString();
}

String? canonicalAnitabiImageUrl(
  String? url, {
  AnitabiServiceConfig? serviceConfig,
}) {
  if (url == null || url.isEmpty) {
    return url;
  }

  final uri = Uri.tryParse(url);
  final config = serviceConfig ?? AnitabiServiceConfig.current;
  final relativePath = _knownImageRelativePath(uri, config);
  if (uri == null || relativePath == null) {
    return url;
  }
  return Uri(
    scheme: 'https',
    host: anitabiOfficialImageHost,
    path: relativePath,
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
  ).toString();
}

String? resolveAnitabiImageUrl(
  String? url, {
  AnitabiImageSource source = AnitabiImageSource.auto,
  AnitabiServiceConfig? serviceConfig,
}) {
  if (url == null || url.isEmpty) {
    return url;
  }

  final uri = Uri.tryParse(url);
  final config = serviceConfig ?? AnitabiServiceConfig.current;
  final requestUri = _imageRequestUri(uri, config);
  if (requestUri == null) {
    return url;
  }

  return switch (source) {
    AnitabiImageSource.mirror => config.mirrorImageUrl(requestUri),
    _ => config.officialImageUrl(requestUri),
  };
}

List<String> candidateAnitabiImageUrls(
  String? url, {
  AnitabiImageSource source = AnitabiImageSource.auto,
  AnitabiServiceConfig? serviceConfig,
}) {
  if (url == null || url.isEmpty) {
    return const [];
  }

  final config = serviceConfig ?? AnitabiServiceConfig.current;
  final resolved = resolveAnitabiImageUrl(
    url,
    source: source,
    serviceConfig: config,
  );
  if (resolved == null || resolved.isEmpty) {
    return const [];
  }

  final originalUri = Uri.tryParse(url);
  final requestUri = _imageRequestUri(originalUri, config);
  if (requestUri == null) {
    return [resolved];
  }

  return switch (source) {
    AnitabiImageSource.official => [config.officialImageUrl(requestUri)],
    AnitabiImageSource.mirror => [config.mirrorImageUrl(requestUri)],
    AnitabiImageSource.auto => [
      config.officialImageUrl(requestUri),
      config.mirrorImageUrl(requestUri),
    ],
  };
}

Uri? _imageRequestUri(Uri? uri, AnitabiServiceConfig config) {
  final relativePath = _knownImageRelativePath(uri, config);
  if (uri == null || relativePath == null) {
    return null;
  }
  return uri.replace(path: relativePath);
}

String? _knownImageRelativePath(Uri? uri, AnitabiServiceConfig config) {
  if (uri == null) {
    return null;
  }
  if (anitabiImageHosts.contains(uri.host)) {
    return uri.path;
  }
  for (final baseUrl in [
    config.officialImageBaseUrl,
    config.mirrorImageBaseUrl,
  ]) {
    final base = Uri.tryParse(baseUrl);
    if (base == null || uri.scheme != base.scheme || uri.host != base.host) {
      continue;
    }
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    if (basePath.isEmpty) {
      return uri.path;
    }
    if (uri.path == basePath || uri.path.startsWith('$basePath/')) {
      final relative = uri.path.substring(basePath.length);
      return relative.isEmpty ? '/' : relative;
    }
  }
  return null;
}
