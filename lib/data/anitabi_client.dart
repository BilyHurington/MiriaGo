import 'dart:convert';

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
    final cn = (json['cn'] as String?)?.trim();
    final name = (json['name'] as String?)?.trim() ?? 'Anitabi 点位';
    final ep = json['ep'];
    final second = json['s'];

    return AnitabiPoint(
      bangumiId: bangumiId,
      id: json['id'] as String,
      name: cn?.isNotEmpty == true ? cn! : name,
      subtitle: name,
      position: LatLng((geo[0] as num).toDouble(), (geo[1] as num).toDouble()),
      episodeLabel: _episodeLabel(ep, second),
      referenceImageUrl: anitabiFullResolutionImageUrl(
        json['image'] as String?,
      ),
      origin: json['origin'] as String? ?? 'Anitabi',
      originUrl: json['originURL'] as String?,
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
    if (second == null) {
      return epText;
    }

    return '$epText / ${second}s';
  }
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
