const defaultAnitabiSiteBaseUrl = 'https://www.anitabi.cn';
const defaultAnitabiStaticDataBaseUrl = 'https://www.anitabi.cn/d';

/// Defaults used while www.anitabi.cn was unavailable. Settings saved with
/// them (i.e. never customised) move back to the restored defaults; the
/// temporary host serves identical data, so a deliberate choice loses nothing.
const legacyTemporaryAnitabiDefaults = {
  'https://ww.anitabi.cn': defaultAnitabiSiteBaseUrl,
  'https://ww.anitabi.cn/d': defaultAnitabiStaticDataBaseUrl,
};
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
  final normalized = uri.replace(path: normalizedPath).toString();
  return legacyTemporaryAnitabiDefaults[normalized] ?? normalized;
}

String? validateAnitabiBaseUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return '请输入有效的 HTTPS 地址';
  }
  if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
    return '地址不能包含账号、查询参数或片段';
  }
  if (isLocalOrPrivateHost(uri.host)) {
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

/// Whether [host] names this device, the local network or a reserved
/// address, in any spelling the network stack would accept: IPv6 (with or
/// without brackets, IPv4-mapped, NAT64), a trailing dot, or a numeric IPv4
/// form other than plain dotted decimal (e.g. `2130706433`, `0x7f.1`), which
/// is refused outright. Names are not resolved.
bool isLocalOrPrivateHost(String host) {
  var normalized = host.toLowerCase().trim();
  if (normalized.startsWith('[') && normalized.endsWith(']')) {
    normalized = normalized.substring(1, normalized.length - 1);
  }
  while (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.isEmpty ||
      normalized == 'localhost' ||
      _localSuffixes.any(normalized.endsWith)) {
    return true;
  }
  if (normalized.contains(':')) {
    final List<int> bytes;
    try {
      bytes = Uri.parseIPv6Address(normalized.split('%').first);
    } on FormatException {
      return true;
    }
    return _isReservedIPv6(bytes);
  }
  // Dart keeps non-ASCII and percent-encoded host characters as they are,
  // while browsers and web views decode and IDNA-map them (a full-width
  // "１２７.０.０.１" becomes 127.0.0.1). Real internationalised names arrive
  // as punycode, so anything else is refused.
  if (!_asciiHost.hasMatch(normalized)) {
    return true;
  }
  if (!_numericHost.hasMatch(normalized)) {
    return false;
  }
  final parts = normalized.split('.');
  final octets = [
    for (final part in parts)
      if (_decimalOctet.hasMatch(part)) int.parse(part),
  ];
  if (parts.length != 4 ||
      octets.length != 4 ||
      octets.any((octet) => octet > 255)) {
    return true;
  }
  return _isReservedIPv4(octets);
}

/// Names reserved for private networks (RFC 6762, 6761, 8375; ICANN's
/// `.internal`) and the widely used `.lan`.
const _localSuffixes = [
  '.localhost',
  '.local',
  '.home.arpa',
  '.internal',
  '.lan',
];

final _asciiHost = RegExp(r'^[a-z0-9._-]+$');
final _numericHost = RegExp(r'^(0x[0-9a-f]*|\d+)(\.(0x[0-9a-f]*|\d+))*$');
final _decimalOctet = RegExp(r'^(0|[1-9]\d{0,2})$');

bool _isReservedIPv4(List<int> octets) {
  final first = octets[0];
  final second = octets[1];
  return first == 0 ||
      first == 10 ||
      (first == 100 && second >= 64 && second <= 127) ||
      first == 127 ||
      (first == 169 && second == 254) ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 0 && octets[2] == 0) ||
      (first == 192 && second == 168) ||
      (first == 198 && (second == 18 || second == 19)) ||
      first >= 224;
}

bool _isReservedIPv6(List<int> bytes) {
  bool zero(int from, int to) =>
      bytes.sublist(from, to).every((byte) => byte == 0);
  final embeddedIPv4 = bytes.sublist(12, 16);
  // ::, ::1 and IPv4-compatible (::a.b.c.d).
  if (zero(0, 12)) {
    return true;
  }
  // IPv4-mapped (::ffff:a.b.c.d).
  if (zero(0, 10) && bytes[10] == 0xff && bytes[11] == 0xff) {
    return _isReservedIPv4(embeddedIPv4);
  }
  // NAT64 (64:ff9b::a.b.c.d).
  if (bytes[0] == 0x00 &&
      bytes[1] == 0x64 &&
      bytes[2] == 0xff &&
      bytes[3] == 0x9b &&
      zero(4, 12)) {
    return _isReservedIPv4(embeddedIPv4);
  }
  // Local-use NAT64 (64:ff9b:1::/48) reaches the gateway's private side.
  if (bytes[0] == 0x00 &&
      bytes[1] == 0x64 &&
      bytes[2] == 0xff &&
      bytes[3] == 0x9b &&
      bytes[4] == 0x00 &&
      bytes[5] == 0x01) {
    return true;
  }
  return (bytes[0] & 0xfe) == 0xfc || // unique local fc00::/7
      (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) || // link local
      (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0xc0) || // site local
      bytes[0] == 0xff; // multicast
}
