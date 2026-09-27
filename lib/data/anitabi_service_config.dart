const defaultAnitabiSiteBaseUrl = 'https://ww.anitabi.cn';
const defaultAnitabiStaticDataBaseUrl = 'https://ww.anitabi.cn/d';
const defaultAnitabiApiBaseUrl = 'https://api.anitabi.cn';
const defaultAnitabiOfficialImageBaseUrl = 'https://image.anitabi.cn';
const defaultAnitabiMirrorImageBaseUrl = 'https://img-tc.anitabi.cn';

class AnitabiServiceConfig {
  const AnitabiServiceConfig({
    this.siteBaseUrl = defaultAnitabiSiteBaseUrl,
    this.staticDataBaseUrl = defaultAnitabiStaticDataBaseUrl,
    this.apiBaseUrl = defaultAnitabiApiBaseUrl,
    this.officialImageBaseUrl = defaultAnitabiOfficialImageBaseUrl,
    this.mirrorImageBaseUrl = defaultAnitabiMirrorImageBaseUrl,
  });

  final String siteBaseUrl;
  final String staticDataBaseUrl;
  final String apiBaseUrl;
  final String officialImageBaseUrl;
  final String mirrorImageBaseUrl;

  static AnitabiServiceConfig current = const AnitabiServiceConfig();

  Uri siteUri(String path, {Map<String, String>? queryParameters}) =>
      _resolve(siteBaseUrl, path, queryParameters: queryParameters);

  Uri staticDataUri(String fileName, {String? version}) => _resolve(
    staticDataBaseUrl,
    fileName,
    queryParameters: version == null || version.isEmpty ? null : {'v': version},
  );

  Uri apiUri(String path, {Map<String, String>? queryParameters}) =>
      _resolve(apiBaseUrl, path, queryParameters: queryParameters);

  String officialImageUrl(Uri original) => _resolve(
    officialImageBaseUrl,
    original.path,
    queryParameters: original.queryParameters,
  ).toString();

  String mirrorImageUrl(Uri original) => _resolve(
    mirrorImageBaseUrl,
    original.path,
    queryParameters: original.queryParameters,
  ).toString();
}

String normalizeAnitabiBaseUrl(String value, {required String fallback}) {
  final trimmed = value.trim();
  if (validateAnitabiBaseUrl(trimmed) != null) {
    return fallback;
  }
  final uri = Uri.parse(trimmed);
  final normalizedPath = uri.path == '/'
      ? ''
      : uri.path.replaceFirst(RegExp(r'/+$'), '');
  return uri.replace(path: normalizedPath).toString();
}

String? validateAnitabiBaseUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return '请输入有效的 HTTPS 地址';
  }
  if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
    return '地址不能包含账号、查询参数或片段';
  }
  if (_isLocalOrPrivateHost(uri.host)) {
    return '不能使用本机或局域网地址';
  }
  return null;
}

Uri _resolve(
  String baseUrl,
  String path, {
  Map<String, String>? queryParameters,
}) {
  final base = Uri.parse(baseUrl);
  final baseSegments = base.pathSegments.where((segment) => segment.isNotEmpty);
  final pathSegments = Uri.parse(
    path,
  ).pathSegments.where((segment) => segment.isNotEmpty);
  return base.replace(
    pathSegments: [...baseSegments, ...pathSegments],
    queryParameters: queryParameters == null || queryParameters.isEmpty
        ? null
        : queryParameters,
  );
}

bool _isLocalOrPrivateHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized == 'localhost' ||
      normalized.endsWith('.localhost') ||
      normalized.endsWith('.local') ||
      normalized == '::1') {
    return true;
  }
  final parts = normalized.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((part) => part == null)) {
    return false;
  }
  final first = parts[0]!;
  final second = parts[1]!;
  return first == 0 ||
      first == 10 ||
      first == 127 ||
      (first == 169 && second == 254) ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168);
}
