class AnitabiImportLink {
  const AnitabiImportLink({required this.bangumiId, required this.pointId});

  final int? bangumiId;
  final String? pointId;

  bool get hasBangumiId => bangumiId != null;
  bool get hasPointId => pointId != null && pointId!.isNotEmpty;
}

AnitabiImportLink? parseAnitabiImportLink(String input) {
  final text = input.trim();
  if (text.isEmpty) {
    return null;
  }

  final uri = _parseUri(text);
  if (uri == null) {
    return null;
  }

  final bangumiId = _firstIntQuery(uri, const [
    'bangumiId',
    'bangumi',
    'bid',
    'subject_id',
    'subjectId',
  ]);
  final pointId = _firstTextQuery(uri, const [
    'pid',
    'pointId',
    'pointID',
    'id',
  ]);
  if (bangumiId == null && pointId == null) {
    return null;
  }

  return AnitabiImportLink(bangumiId: bangumiId, pointId: pointId);
}

Uri? _parseUri(String text) {
  final direct = Uri.tryParse(text);
  if (direct != null && direct.hasScheme) {
    return direct;
  }
  final queryStart = text.indexOf('?');
  if (queryStart >= 0) {
    // A link pasted without its scheme, e.g. `anitabi.cn/map?bangumiId=1`.
    if (_hostLikePrefix.hasMatch(text.substring(0, queryStart))) {
      final withScheme = Uri.tryParse('https://$text');
      if (withScheme != null && withScheme.host.isNotEmpty) {
        return withScheme;
      }
    }
    // A bare path or query such as `/map?bangumiId=1` or `?bangumiId=1`.
    return Uri.tryParse('https://anitabi.cn/map${text.substring(queryStart)}');
  }
  return Uri.tryParse('https://anitabi.cn/map?$text');
}

final _hostLikePrefix = RegExp(
  r'^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?'
  r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+(?::\d+)?(?:/[^?#\s]*)?$',
);

int? _firstIntQuery(Uri uri, List<String> keys) {
  for (final key in keys) {
    final value = uri.queryParameters[key]?.trim();
    if (value == null || value.isEmpty) {
      continue;
    }
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}

String? _firstTextQuery(Uri uri, List<String> keys) {
  for (final key in keys) {
    final value = uri.queryParameters[key]?.trim();
    if (value == null || value.isEmpty) {
      continue;
    }
    if (RegExp(r'^[a-zA-Z0-9_-]{3,64}$').hasMatch(value)) {
      return value;
    }
  }
  return null;
}
