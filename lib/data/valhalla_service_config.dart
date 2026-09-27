const defaultValhallaBaseUrl = 'https://valhalla1.openstreetmap.de';

String normalizeValhallaBaseUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return defaultValhallaBaseUrl;
  }
  return trimmed.replaceFirst(RegExp(r'/+$'), '');
}

String? validateValhallaBaseUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return '请输入完整的服务地址';
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return '服务地址仅支持 HTTP 或 HTTPS';
  }
  return null;
}
