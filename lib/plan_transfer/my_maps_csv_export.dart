import 'dart:convert';

import '../plan/pilgrimage_models.dart';

const myMapsCsvMimeType = 'text/csv';
const myMapsCsvExtension = 'csv';

class MyMapsCsvExportResult {
  const MyMapsCsvExportResult({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.skippedPointCount,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
  final int skippedPointCount;
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
  var skippedPointCount = 0;
  for (final point in plan.points) {
    if (!point.hasCoordinate) {
      skippedPointCount += 1;
      continue;
    }
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

  final csv = rows
      .map(
        (row) => [
          for (var column = 0; column < row.length; column++)
            _csvCell(row[column], numeric: _numericColumns.contains(column)),
        ].join(','),
      )
      .join('\r\n');
  return MyMapsCsvExportResult(
    bytes: utf8.encode(csv),
    fileName: suggestMyMapsCsvFileName(plan: plan, exportedAt: exportTime),
    mimeType: myMapsCsvMimeType,
    skippedPointCount: skippedPointCount,
  );
}

String suggestMyMapsCsvFileName({
  required PilgrimagePlan plan,
  required DateTime exportedAt,
}) {
  return '${_safeFileName(plan.name, fallback: 'miriago_plan')}_mymaps_${_timestamp(exportedAt)}.$myMapsCsvExtension';
}

// Lat/Long must stay raw numbers so My Maps can place the points; every other
// column is user text and gets formula-injection protection.
const _numericColumns = {1, 2};

String _csvCell(String value, {required bool numeric}) {
  final line = _singleLine(value);
  final text = numeric ? line : _neutralizeSpreadsheetFormula(line);
  final escaped = text.replaceAll('"', '""');
  if (escaped.contains(',') ||
      escaped.contains('"') ||
      escaped.contains('\n') ||
      escaped.contains('\r')) {
    return '"$escaped"';
  }
  return escaped;
}

// Spreadsheet apps (Excel, Sheets, LibreOffice) evaluate cells starting with
// these characters as formulas; a leading apostrophe forces plain text.
String _neutralizeSpreadsheetFormula(String value) {
  if (value.isEmpty) {
    return value;
  }
  return const {'=', '+', '-', '@', '\t', '\r'}.contains(value[0])
      ? "'$value"
      : value;
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
