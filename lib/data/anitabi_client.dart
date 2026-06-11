import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../plan/pilgrimage_models.dart';
import 'anitabi_image_url.dart';

class AnitabiClient {
  AnitabiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<AnitabiBangumiLite> fetchBangumiLite(int bangumiId) async {
    final uri = Uri.parse('https://api.anitabi.cn/bangumi/$bangumiId/lite');
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AnitabiException(response.statusCode, response.body);
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    return AnitabiBangumiLite.fromJson(decoded);
  }

  Future<List<AnitabiPoint>> fetchPoints(int bangumiId) async {
    final uri = Uri.parse(
      'https://api.anitabi.cn/bangumi/$bangumiId/points/detail',
    ).replace(queryParameters: const {'haveImage': 'true'});
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AnitabiException(response.statusCode, response.body);
    }

    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .whereType<Map<String, Object?>>()
        .map((json) => AnitabiPoint.fromJson(json, bangumiId: bangumiId))
        .toList(growable: false);
  }

  Future<AnitabiPointLookupResult?> findPointById(String pointId) async {
    final normalizedPointId = pointId.trim();
    if (normalizedPointId.isEmpty) {
      return null;
    }

    final indexResponse = await _getAnitabiStaticJson('g.json');

    final index = jsonDecode(indexResponse.body) as List<Object?>;
    final rawWorks = (index[0] as List<Object?>).whereType<List<Object?>>();
    final pageSize = (index[1] as num).toInt();
    final works = rawWorks
        .map(AnitabiMapWorkLite.fromCompactJson)
        .toList(growable: false);
    final workById = {for (final work in works) work.bangumiId: work};
    final pageCount = (works.length / pageSize).ceil();

    for (var pageIndex = 0; pageIndex < pageCount; pageIndex += 1) {
      final pageResponse = await _getAnitabiStaticJson('g$pageIndex.json');

      final page = (jsonDecode(pageResponse.body) as List<Object?>)
          .whereType<List<Object?>>();
      for (final entry in page) {
        final bangumiId = (entry[0] as num).toInt();
        final pointRows = (entry[2] as List<Object?>)
            .whereType<List<Object?>>();
        for (final pointRow in pointRows) {
          final id = _stringValue(pointRow[0]);
          if (id != normalizedPointId) {
            continue;
          }

          final work = workById[bangumiId];
          final litePoint = work?.pointById(normalizedPointId);
          if (work == null || litePoint == null) {
            return null;
          }

          return AnitabiPointLookupResult(
            work: work.toBangumiLite(),
            point: AnitabiPoint.fromCompactJson(
              pointRow,
              bangumiId: bangumiId,
              position: litePoint.position,
            ),
          );
        }
      }
    }

    return null;
  }

  Future<http.Response> _getAnitabiStaticJson(String fileName) async {
    final primaryUri = Uri.parse('https://www.anitabi.cn/d/$fileName');
    try {
      return await _checkedGet(primaryUri);
    } catch (error) {
      if (!kIsWeb) {
        rethrow;
      }

      final proxyUri = Uri.base.resolve('/__anitabi_static__/$fileName');
      try {
        return await _checkedGet(proxyUri);
      } catch (_) {
        throw AnitabiStaticDataUnavailableException(error);
      }
    }
  }

  Future<http.Response> _checkedGet(Uri uri) async {
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AnitabiException(response.statusCode, response.body);
    }
    return response;
  }
}

class AnitabiBangumiLite {
  const AnitabiBangumiLite({
    required this.bangumiId,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.center,
    required this.zoom,
    required this.pointsLength,
  });

  factory AnitabiBangumiLite.fromJson(Map<String, Object?> json) {
    final geo = (json['geo'] as List<Object?>?) ?? const [35.0, 135.0];
    return AnitabiBangumiLite(
      bangumiId: json['id'] as int,
      title: (json['cn'] as String?)?.isNotEmpty == true
          ? json['cn'] as String
          : json['title'] as String? ?? 'Anitabi',
      subtitle: json['title'] as String? ?? '',
      city: json['city'] as String? ?? '未设置地区',
      center: LatLng((geo[0] as num).toDouble(), (geo[1] as num).toDouble()),
      zoom: (json['zoom'] as num?)?.toDouble() ?? 12,
      pointsLength: json['pointsLength'] as int? ?? 0,
    );
  }

  final int bangumiId;
  final String title;
  final String subtitle;
  final String city;
  final LatLng center;
  final double zoom;
  final int pointsLength;
}

class AnitabiPointLookupResult {
  const AnitabiPointLookupResult({required this.work, required this.point});

  final AnitabiBangumiLite work;
  final AnitabiPoint point;
}

class AnitabiMapWorkLite {
  const AnitabiMapWorkLite({
    required this.bangumiId,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.center,
    required this.zoom,
    required this.points,
  });

  factory AnitabiMapWorkLite.fromCompactJson(List<Object?> json) {
    final centerLat = (json[9] as num?)?.toDouble() ?? 35.0;
    final centerLng = (json[10] as num?)?.toDouble() ?? 135.0;
    return AnitabiMapWorkLite(
      bangumiId: (json[0] as num).toInt(),
      title: _preferredString(json[1], json[3]) ?? 'Anitabi',
      subtitle: _compactStringValue(json[3]) ?? '',
      city: _compactStringValue(json[4]) ?? '未设置地区',
      center: LatLng(centerLat, centerLng),
      zoom: (json[11] as num?)?.toDouble() ?? 12,
      points: _compactLitePoints(json[12]),
    );
  }

  final int bangumiId;
  final String title;
  final String subtitle;
  final String city;
  final LatLng center;
  final double zoom;
  final Map<String, AnitabiMapLitePoint> points;

  AnitabiMapLitePoint? pointById(String pointId) {
    return points[pointId];
  }

  AnitabiBangumiLite toBangumiLite() {
    return AnitabiBangumiLite(
      bangumiId: bangumiId,
      title: title,
      subtitle: subtitle,
      city: city,
      center: center,
      zoom: zoom,
      pointsLength: points.length,
    );
  }

  static Map<String, AnitabiMapLitePoint> _compactLitePoints(Object? value) {
    final rawPoints = value is List<Object?> ? value : const <Object?>[];
    final points = <String, AnitabiMapLitePoint>{};
    for (var index = 0; index + 3 < rawPoints.length; index += 4) {
      final id = _stringValue(rawPoints[index]);
      if (id == null) {
        continue;
      }

      points[id] = AnitabiMapLitePoint(
        id: id,
        position: LatLng(
          (rawPoints[index + 1] as num).toDouble(),
          (rawPoints[index + 2] as num).toDouble(),
        ),
      );
    }
    return points;
  }
}

class AnitabiMapLitePoint {
  const AnitabiMapLitePoint({required this.id, required this.position});

  final String id;
  final LatLng position;
}

class AnitabiPoint {
  const AnitabiPoint({
    required this.bangumiId,
    required this.id,
    required this.name,
    required this.subtitle,
    required this.position,
    required this.episodeLabel,
    required this.referenceImageUrl,
    required this.origin,
    required this.originUrl,
  });

  factory AnitabiPoint.fromJson(
    Map<String, Object?> json, {
    required int bangumiId,
  }) {
    final geo = json['geo'] as List<Object?>;
    final cn = _stringValue(json['cn']);
    final name = _stringValue(json['name']) ?? 'Anitabi 点位';
    final ep = json['ep'];
    final second = json['s'];

    return AnitabiPoint(
      bangumiId: bangumiId,
      id: _stringValue(json['id']) ?? 'unknown',
      name: cn?.isNotEmpty == true ? cn! : name,
      subtitle: name,
      position: LatLng((geo[0] as num).toDouble(), (geo[1] as num).toDouble()),
      episodeLabel: _episodeLabel(ep, second),
      referenceImageUrl: anitabiFullResolutionImageUrl(
        _stringValue(json['image']),
      ),
      origin: _stringValue(json['origin']) ?? 'Anitabi',
      originUrl: _stringValue(json['originURL']),
    );
  }

  factory AnitabiPoint.fromCompactJson(
    List<Object?> json, {
    required int bangumiId,
    required LatLng position,
  }) {
    final cn = _compactStringValue(json[2]);
    final name = _compactStringValue(json[1]) ?? 'Anitabi 点位';
    final ep = json[8];
    final second = json[9];

    return AnitabiPoint(
      bangumiId: bangumiId,
      id: _stringValue(json[0]) ?? 'unknown',
      name: cn?.isNotEmpty == true ? cn! : name,
      subtitle: name,
      position: position,
      episodeLabel: _episodeLabel(ep, second),
      referenceImageUrl: anitabiFullResolutionImageUrl(
        _anitabiImageUrl(_compactStringValue(json[6])),
      ),
      origin: _compactStringValue(json[11]) ?? 'Anitabi',
      originUrl: _compactStringValue(json[12]),
    );
  }

  final int bangumiId;
  final String id;
  final String name;
  final String subtitle;
  final LatLng position;
  final String episodeLabel;
  final String? referenceImageUrl;
  final String origin;
  final String? originUrl;

  PilgrimagePoint toPilgrimagePoint(PilgrimageWork work) {
    return PilgrimagePoint(
      id: 'anitabi-$bangumiId-$id',
      work: work,
      name: name,
      subtitle: subtitle,
      position: position,
      episodeLabel: episodeLabel,
      referenceLabel: origin,
      source: PointSource.anitabi,
      sourceId: id,
      referenceImageUrl: referenceImageUrl,
      sourceUrl: originUrl,
    );
  }

  static String _episodeLabel(Object? ep, Object? second) {
    final epText = ep == null ? 'EP ?' : 'EP $ep';
    final sceneTime = formatAnitabiSceneTime(second);
    if (sceneTime == null) {
      return epText;
    }

    return '$epText / $sceneTime';
  }
}

String? _stringValue(Object? value) {
  final text = value?.toString().trim();
  return text?.isEmpty == true ? null : text;
}

String? _preferredString(Object? primary, Object? fallback) {
  return _compactStringValue(primary) ?? _compactStringValue(fallback);
}

String? _compactStringValue(Object? value) {
  if (value == null || value == 0 || value == false) {
    return null;
  }
  return _stringValue(value);
}

String? _anitabiImageUrl(String? url) {
  if (url == null || url.isEmpty) {
    return url;
  }
  if (url.startsWith('/images/')) {
    return 'https://image.anitabi.cn${url.substring('/images'.length)}';
  }
  return url;
}

String? formatAnitabiSceneTime(Object? second) {
  return formatSceneSeconds(second);
}

class AnitabiException implements Exception {
  const AnitabiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() {
    return 'AnitabiException($statusCode): $body';
  }
}

class AnitabiPointNotFoundException implements Exception {
  const AnitabiPointNotFoundException();

  @override
  String toString() {
    return '没有找到对应的 Anitabi 点位';
  }
}

class AnitabiStaticDataUnavailableException implements Exception {
  const AnitabiStaticDataUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() {
    return 'Anitabi static map data is unavailable: $cause';
  }
}
