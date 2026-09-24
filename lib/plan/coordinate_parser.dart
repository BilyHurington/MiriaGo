import 'package:latlong2/latlong.dart';

import 'clipboard_text_stub.dart'
    if (dart.library.js_interop) 'clipboard_text_web.dart';

LatLng? parseCoordinateText(String input) {
  final normalized = _normalizeCoordinateText(input);
  if (normalized.isEmpty) {
    return null;
  }

  final decimal = _parseDecimalCoordinate(normalized);
  if (decimal != null) {
    return decimal;
  }

  return _parseDmsCoordinate(normalized);
}

/// Parses one latitude or longitude typed into a manual coordinate field.
///
/// Full-width digits are accepted. Returns null for text that is not a number,
/// is not finite (`NaN`, `Infinity`) or is outside the valid range.
double? parseCoordinateComponent(String input, {required bool latitude}) {
  final value = double.tryParse(_normalizeCoordinateText(input));
  final limit = latitude ? 90.0 : 180.0;
  if (value == null || !value.isFinite || value < -limit || value > limit) {
    return null;
  }
  return value;
}

Future<LatLng?> parseClipboardCoordinate() async {
  final text = await readClipboardText();
  return parseCoordinateText(text ?? '');
}

String _normalizeCoordinateText(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    buffer.writeCharCode(_normalizeFullWidthRune(rune));
  }
  return buffer
      .toString()
      .trim()
      .replaceAll('、', ',')
      .replaceAll('−', '-')
      // The katakana prolonged sound mark is a common IME slip for a minus
      // sign; only treat it as one when it directly precedes a number.
      .replaceAll(RegExp(r'ー(?=\s*\d)'), '-')
      .replaceAll('º', '°')
      .replaceAll(RegExp(r'\s+'), ' ');
}

int _normalizeFullWidthRune(int rune) {
  // Full-width digits, letters and punctuation (U+FF01-U+FF5E, e.g. `３`,
  // `．`, `，`, `－`, `Ｎ`) map directly onto ASCII U+0021-U+007E.
  if (rune >= 0xFF01 && rune <= 0xFF5E) {
    return rune - 0xFEE0;
  }
  if (rune == 0x3000) {
    return 0x20;
  }
  return rune;
}

LatLng? _parseDecimalCoordinate(String input) {
  final match = RegExp(
    r'^\s*([+-]?\d+(?:\.\d+)?)\s*[,;\s]\s*([+-]?\d+(?:\.\d+)?)\s*$',
  ).firstMatch(input);
  if (match == null) {
    return null;
  }

  final latitude = double.tryParse(match.group(1)!);
  final longitude = double.tryParse(match.group(2)!);
  return _validatedLatLng(latitude, longitude);
}

final _directionPattern = RegExp(
  r'(?<![A-Za-z])[NSEW](?![A-Za-z])',
  caseSensitive: false,
);

/// Parses coordinates that carry N/S/E/W hemisphere letters, in either prefix
/// (`N35°40′ E139°46′`) or suffix (`35°40′N 139°46′E`) form.
///
/// The form is decided once per string: text that starts with a direction
/// letter uses prefixes throughout, anything else uses suffixes. Each letter
/// owns only the numbers between it and its neighbour, so a number is never
/// shared between latitude and longitude.
LatLng? _parseDmsCoordinate(String input) {
  final directions = _directionPattern.allMatches(input).toList();
  if (directions.length != 2) {
    return null;
  }

  final isPrefix = directions.first.start == 0;
  if (!isPrefix &&
      RegExp(r'\d').hasMatch(input.substring(directions.last.end))) {
    return null;
  }

  double? latitude;
  double? longitude;
  for (var index = 0; index < directions.length; index += 1) {
    final match = directions[index];
    final String segment;
    if (isPrefix) {
      final end = index + 1 < directions.length
          ? directions[index + 1].start
          : input.length;
      segment = input.substring(match.end, end);
    } else {
      final start = index == 0 ? 0 : directions[index - 1].end;
      segment = input.substring(start, match.start);
    }

    final direction = match.group(0)!.toUpperCase();
    final value = _dmsSegmentValue(segment, direction);
    if (value == null) {
      return null;
    }
    if (direction == 'N' || direction == 'S') {
      if (latitude != null) {
        return null;
      }
      latitude = value;
    } else {
      if (longitude != null) {
        return null;
      }
      longitude = value;
    }
  }

  return _validatedLatLng(latitude, longitude);
}

double? _dmsSegmentValue(String segment, String direction) {
  final values = RegExp(
    r'\d+(?:\.\d+)?',
  ).allMatches(segment).map((match) => match.group(0)!).toList();
  if (values.isEmpty || values.length > 3) {
    return null;
  }
  return _dmsValue(
    degrees: values[0],
    minutes: values.length > 1 ? values[1] : null,
    seconds: values.length > 2 ? values[2] : null,
    direction: direction,
  );
}

double? _dmsValue({
  required String degrees,
  required String? minutes,
  required String? seconds,
  required String direction,
}) {
  final degreeValue = double.parse(degrees);
  final minuteValue = minutes == null ? 0.0 : double.parse(minutes);
  final secondValue = seconds == null ? 0.0 : double.parse(seconds);
  if (minuteValue >= 60 || secondValue >= 60) {
    return null;
  }
  final sign = direction == 'S' || direction == 'W' ? -1.0 : 1.0;
  return sign * (degreeValue + minuteValue / 60 + secondValue / 3600);
}

LatLng? _validatedLatLng(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) {
    return null;
  }
  if (!latitude.isFinite || !longitude.isFinite) {
    return null;
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return LatLng(latitude, longitude);
}
