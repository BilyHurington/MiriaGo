import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/bangumi_config.dart';
import '../plan/pilgrimage_models.dart';

class BangumiApiClient {
  BangumiApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<List<PilgrimageWork>> searchSubjects(
    String keyword, {
    required Set<BangumiSubjectType> types,
  }) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      return const [];
    }

    final uri = Uri.parse(
      '${BangumiConfig.apiBaseUrl}/v0/search/subjects',
    ).replace(queryParameters: const {'limit': '12'});
    final response = await _httpClient.post(
      uri,
      headers: const {
        'Authorization': 'Bearer ${BangumiConfig.apiToken}',
        'User-Agent': BangumiConfig.userAgent,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'keyword': query,
        'sort': 'match',
        if (types.isNotEmpty)
          'filter': {
            'type': types.map((type) => type.code).toList(growable: false),
          },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BangumiApiException(response.statusCode, response.body);
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final data = decoded['data'];
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, Object?>>()
        .map(_workFromSubject)
        .toList(growable: false);
  }

  Future<List<PilgrimageWork>> searchAnime(String keyword) {
    return searchSubjects(keyword, types: const {BangumiSubjectType.anime});
  }

  PilgrimageWork _workFromSubject(Map<String, Object?> subject) {
    final bangumiId = subject['id'] as int;
    final subjectType = BangumiSubjectType.fromCode(subject['type'] as int?);
    final name = subject['name'] as String? ?? 'Bangumi #$bangumiId';
    final nameCn = subject['name_cn'] as String? ?? '';
    final date = subject['date'] as String? ?? '';
    final title = nameCn.isEmpty ? name : nameCn;
    final subtitle = nameCn.isEmpty ? 'Bangumi #$bangumiId' : name;

    final metaParts = [
      if (subjectType != null) subjectType.label,
      if (date.isNotEmpty) date,
    ];

    return PilgrimageWork(
      id: 'bangumi-$bangumiId',
      bangumiId: bangumiId,
      bangumiSubjectType: subjectType,
      title: title,
      subtitle: subtitle,
      city: metaParts.isEmpty ? '未设置地区' : metaParts.join(' / '),
      source: WorkSource.bangumi,
    );
  }
}

class BangumiApiException implements Exception {
  const BangumiApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() {
    return 'BangumiApiException($statusCode): $body';
  }
}
