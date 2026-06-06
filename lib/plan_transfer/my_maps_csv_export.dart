import 'dart:convert';

import '../plan/pilgrimage_models.dart';

const myMapsCsvMimeType = 'text/csv';
const myMapsCsvExtension = 'csv';

class MyMapsCsvExportResult {
  const MyMapsCsvExportResult({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
}

MyMapsCsvExportResult buildMyMapsCsvExport({
  required PilgrimagePlan plan,
  DateTime? exportedAt,
}) {
  final exportTime = exportedAt ?? DateTime.now();
  final rows = <List<String>>[
    const [
      'Name',
      'Lat',
      'Long',
      'Type',
      'Description',
      'URL link',
      'Work',
      'Episode',
      'Scene',
      'Anitabi ID',
      'Source URL',
    ],
  ];

  final groupsById = {for (final group in plan.groups) group.id: group};
  for (final point in plan.points) {
    final group = point.groupId == null ? null : groupsById[point.groupId];
    final groupName = group?.name ?? '未分组';
    rows.add([
      point.name,
      point.position.latitude.toStringAsFixed(7),
      point.position.longitude.toStringAsFixed(7),
      groupName,
      point.subtitle,
      point.referenceImageUrl ?? point.sourceUrl ?? '',
      point.work.title,
      point.displayEpisodeLabel,
      point.subtitle,
      point.source == PointSource.anitabi ? point.sourceId ?? '' : '',
      point.sourceUrl ?? '',
    ]);
  }

  final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  return MyMapsCsvExportResult(
    bytes: utf8.encode(csv),
    fileName: suggestMyMapsCsvFileName(plan: plan, exportedAt: exportTime),
    mimeType: myMapsCsvMimeType,
  );
}

String suggestMyMapsCsvFileName({
  required PilgrimagePlan plan,
  required DateTime exportedAt,
}) {
  return '${_safeFileName(plan.name, fallback: 'miriago_plan')}_mymaps_${_timestamp(exportedAt)}.$myMapsCsvExtension';
}

String _csvCell(String value) {
  final escaped = _singleLine(value).replaceAll('"', '""');
  if (escaped.contains(',') ||
      escaped.contains('"') ||
      escaped.contains('\n') ||
      escaped.contains('\r')) {
    return '"$escaped"';
  }
  return escaped;
}

String _singleLine(String value) {
  return value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
}

String _safeFileName(String source, {required String fallback}) {
  final safeName = source
      .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return safeName.isEmpty ? fallback : safeName;
}

String _timestamp(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}_${twoDigits(value.hour)}${twoDigits(value.minute)}';
}
