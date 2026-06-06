String? anitabiFullResolutionImageUrl(String? url) {
  if (url == null || url.isEmpty) {
    return url;
  }

  final uri = Uri.tryParse(url);
  if (uri == null || uri.host != 'image.anitabi.cn') {
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
  if (uri == null || uri.host != 'image.anitabi.cn') {
    return fullUrl;
  }

  return uri
      .replace(queryParameters: {...uri.queryParameters, 'plan': 'h160'})
      .toString();
}
