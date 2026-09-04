import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/valhalla_service_config.dart';

class NavigationRoute {
  const NavigationRoute({
    required this.shape,
    required this.maneuvers,
    required this.distanceKm,
    required this.duration,
  });

  final List<LatLng> shape;
  final List<NavigationManeuver> maneuvers;
  final double distanceKm;
  final Duration duration;
}

class NavigationManeuver {
  const NavigationManeuver({
    required this.type,
    required this.instruction,
    required this.distanceKm,
    required this.beginShapeIndex,
    required this.endShapeIndex,
  });

  final int type;
  final String instruction;
  final double distanceKm;
  final int beginShapeIndex;
  final int endShapeIndex;
}

class ValhallaRouteException implements Exception {
  const ValhallaRouteException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ValhallaRouteClient {
  ValhallaRouteClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
    this.cacheDuration = const Duration(minutes: 5),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  final Duration cacheDuration;
  final Map<String, _CachedRoute> _cache = {};

  Future<NavigationRoute> route({
    required String baseUrl,
    required List<LatLng> locations,
  }) async {
    if (locations.length < 2) {
      throw const ValhallaRouteException('路线至少需要起点和终点');
    }
    final normalizedBaseUrl = normalizeValhallaBaseUrl(baseUrl);
    final validationError = validateValhallaBaseUrl(normalizedBaseUrl);
    if (validationError != null) {
      throw ValhallaRouteException(validationError);
    }

    final cacheKey = _cacheKey(normalizedBaseUrl, locations);
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < cacheDuration) {
      return cached.route;
    }

    final uri = Uri.parse('$normalizedBaseUrl/route');
    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-Client-Id': 'MiriaGo',
            },
            body: jsonEncode({
              'locations': [
                for (final point in locations)
                  {
                    'lat': point.latitude,
                    'lon': point.longitude,
                    'type': 'break',
                  },
              ],
              'costing': 'pedestrian',
              'units': 'kilometers',
              'language': 'en-US',
              'directions_options': {'units': 'kilometers'},
              'shape_format': 'polyline6',
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ValhallaRouteException('路径规划服务响应超时，请稍后重试');
    } on Object catch (error) {
      throw ValhallaRouteException('无法连接路径规划服务：$error');
    }

    if (response.statusCode == 429) {
      throw const ValhallaRouteException('路径规划服务请求过于频繁，请稍后重试');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ValhallaRouteException(
        response.statusCode >= 500
            ? '路径规划服务暂时不可用（${response.statusCode}）'
            : '无法规划这条步行路线（${response.statusCode}）',
      );
    }

    final parsed = _parseRoute(response.body);
    _cache[cacheKey] = _CachedRoute(parsed, DateTime.now());
    _cache.removeWhere(
      (_, entry) => DateTime.now().difference(entry.createdAt) >= cacheDuration,
    );
    return parsed;
  }

  Future<void> testConnection(String baseUrl) async {
    final normalized = normalizeValhallaBaseUrl(baseUrl);
    final validationError = validateValhallaBaseUrl(normalized);
    if (validationError != null) {
      throw ValhallaRouteException(validationError);
    }
    try {
      final response = await _client
          .get(
            Uri.parse('$normalized/status'),
            headers: const {
              'Accept': 'application/json',
              'X-Client-Id': 'MiriaGo',
            },
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ValhallaRouteException('服务返回 ${response.statusCode}');
      }
    } on TimeoutException {
      throw const ValhallaRouteException('连接测试超时');
    }
  }

  NavigationRoute _parseRoute(String body) {
    try {
      final root = jsonDecode(body) as Map<String, dynamic>;
      final trip = root['trip'] as Map<String, dynamic>;
      final summary = trip['summary'] as Map<String, dynamic>;
      final legs = (trip['legs'] as List<dynamic>).cast<Map<String, dynamic>>();
      final shape = <LatLng>[];
      final maneuvers = <NavigationManeuver>[];

      for (final leg in legs) {
        final legShape = decodePolyline6(leg['shape'] as String);
        final sharesFirstPoint =
            shape.isNotEmpty &&
            legShape.isNotEmpty &&
            shape.last == legShape.first;
        final offset = sharesFirstPoint ? shape.length - 1 : shape.length;
        if (sharesFirstPoint) {
          shape.addAll(legShape.skip(1));
        } else {
          shape.addAll(legShape);
        }
        for (final raw in (leg['maneuvers'] as List<dynamic>? ?? const [])) {
          final maneuver = raw as Map<String, dynamic>;
          final type = (maneuver['type'] as num?)?.toInt() ?? 0;
          final begin = (maneuver['begin_shape_index'] as num?)?.toInt() ?? 0;
          final end = (maneuver['end_shape_index'] as num?)?.toInt() ?? begin;
          maneuvers.add(
            NavigationManeuver(
              type: type,
              instruction: localizedManeuverInstruction(
                type,
                streetNames:
                    (maneuver['street_names'] as List<dynamic>? ?? const [])
                        .whereType<String>()
                        .toList(growable: false),
                fallbackInstruction: maneuver['instruction'] as String?,
              ),
              distanceKm: (maneuver['length'] as num?)?.toDouble() ?? 0,
              beginShapeIndex: (offset + begin).clamp(0, shape.length - 1),
              endShapeIndex: (offset + end).clamp(0, shape.length - 1),
            ),
          );
        }
      }
      if (shape.length < 2) {
        throw const FormatException('missing route shape');
      }
      return NavigationRoute(
        shape: List.unmodifiable(shape),
        maneuvers: List.unmodifiable(maneuvers),
        distanceKm: (summary['length'] as num?)?.toDouble() ?? 0,
        duration: Duration(seconds: (summary['time'] as num?)?.round() ?? 0),
      );
    } on Object {
      throw const ValhallaRouteException('路径规划服务返回了无法识别的数据');
    }
  }
}

String localizedManeuverInstruction(
  int type, {
  List<String> streetNames = const [],
  String? fallbackInstruction,
}) {
  final road = streetNames.where((name) => name.trim().isNotEmpty).firstOrNull;
  final ontoRoad = road == null ? '' : '进入$road';
  final alongRoad = road == null ? '' : '沿$road';
  // Values follow Valhalla Directions Maneuver.Type.
  return switch (type) {
    1 => alongRoad.isEmpty ? '开始步行' : '$alongRoad出发',
    2 => ontoRoad.isEmpty ? '向右出发' : '向右出发，$ontoRoad',
    3 => ontoRoad.isEmpty ? '向左出发' : '向左出发，$ontoRoad',
    4 || 5 || 6 => road == null ? '到达终点' : '到达$road附近的终点',
    7 => ontoRoad.isEmpty ? '继续前行' : '继续前行，$ontoRoad',
    8 => alongRoad.isEmpty ? '继续直行' : '$alongRoad继续直行',
    9 => ontoRoad.isEmpty ? '稍向右转' : '稍向右转，$ontoRoad',
    10 => ontoRoad.isEmpty ? '向右转' : '向右转，$ontoRoad',
    11 => ontoRoad.isEmpty ? '向右急转' : '向右急转，$ontoRoad',
    12 || 13 => '请掉头',
    14 => ontoRoad.isEmpty ? '向左急转' : '向左急转，$ontoRoad',
    15 => ontoRoad.isEmpty ? '向左转' : '向左转，$ontoRoad',
    16 => ontoRoad.isEmpty ? '稍向左转' : '稍向左转，$ontoRoad',
    17 => alongRoad.isEmpty ? '沿匝道直行' : '$alongRoad沿匝道直行',
    18 => ontoRoad.isEmpty ? '沿右侧匝道前行' : '沿右侧匝道$ontoRoad',
    19 => ontoRoad.isEmpty ? '沿左侧匝道前行' : '沿左侧匝道$ontoRoad',
    20 => '从右侧出口离开',
    21 => '从左侧出口离开',
    22 => alongRoad.isEmpty ? '保持直行' : '$alongRoad保持直行',
    23 => alongRoad.isEmpty ? '靠右行走' : '$alongRoad靠右行走',
    24 => alongRoad.isEmpty ? '靠左行走' : '$alongRoad靠左行走',
    25 => ontoRoad.isEmpty ? '汇入道路' : '汇入道路，$ontoRoad',
    26 => '进入环岛',
    27 => '驶出环岛',
    28 => '进入渡轮',
    29 => '离开渡轮',
    30 => '搭乘公共交通',
    31 || 34 => '换乘',
    32 => '继续乘坐当前线路',
    33 => '前往公共交通连接点',
    35 || 36 => '到达公共交通目的地',
    37 => ontoRoad.isEmpty ? '向右汇入道路' : '向右汇入道路，$ontoRoad',
    38 => ontoRoad.isEmpty ? '向左汇入道路' : '向左汇入道路，$ontoRoad',
    39 => '乘坐电梯',
    40 => '走楼梯',
    41 => '乘坐自动扶梯',
    42 => '进入建筑',
    43 => '离开建筑',
    44 => '前往其他楼层',
    45 => '停放车辆后继续步行',
    _ =>
      fallbackInstruction?.trim().isNotEmpty == true
          ? fallbackInstruction!.trim()
          : (alongRoad.isEmpty ? '继续前行' : '$alongRoad继续前行'),
  };
}

List<LatLng> decodePolyline6(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;
  while (index < encoded.length) {
    final latitudeResult = _decodeCoordinate(encoded, index);
    index = latitudeResult.nextIndex;
    latitude += latitudeResult.delta;
    final longitudeResult = _decodeCoordinate(encoded, index);
    index = longitudeResult.nextIndex;
    longitude += longitudeResult.delta;
    points.add(LatLng(latitude / 1e6, longitude / 1e6));
  }
  return points;
}

_DecodedCoordinate _decodeCoordinate(String encoded, int startIndex) {
  var result = 0;
  var shift = 0;
  var index = startIndex;
  int byte;
  do {
    if (index >= encoded.length) {
      throw const FormatException('truncated polyline');
    }
    byte = encoded.codeUnitAt(index++) - 63;
    result |= (byte & 0x1f) << shift;
    shift += 5;
  } while (byte >= 0x20);
  final delta = (result & 1) == 1 ? ~(result >> 1) : result >> 1;
  return _DecodedCoordinate(delta, index);
}

String _cacheKey(String baseUrl, List<LatLng> points) => [
  baseUrl,
  for (final point in points)
    '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}',
].join('|');

class _CachedRoute {
  const _CachedRoute(this.route, this.createdAt);
  final NavigationRoute route;
  final DateTime createdAt;
}

class _DecodedCoordinate {
  const _DecodedCoordinate(this.delta, this.nextIndex);
  final int delta;
  final int nextIndex;
}
