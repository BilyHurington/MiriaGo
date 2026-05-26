import 'dart:io';

import 'package:image/image.dart' as img;

Future<DateTime?> readGalleryCaptureTime(String imagePath) async {
  try {
    final file = File(imagePath);
    if (!file.existsSync()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    final exif = img.JpegDecoder().decode(bytes)?.exif;
    if (exif == null || exif.isEmpty) {
      return null;
    }

    for (final tagName in const [
      'DateTimeOriginal',
      'DateTimeDigitized',
      'DateTime',
    ]) {
      final value = exif.getTag(img.exifTagNameToID[tagName] ?? -1);
      final parsed = _parseExifDateTime(value?.toString());
      if (parsed != null) {
        return parsed;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

DateTime? _parseExifDateTime(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final match = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(trimmed);
  if (match == null) {
    return null;
  }

  final parts = [
    for (var index = 1; index <= 6; index += 1)
      int.tryParse(match.group(index) ?? ''),
  ];
  if (parts.any((part) => part == null)) {
    return null;
  }

  try {
    return DateTime(
      parts[0]!,
      parts[1]!,
      parts[2]!,
      parts[3]!,
      parts[4]!,
      parts[5]!,
    );
  } catch (_) {
    return null;
  }
}
