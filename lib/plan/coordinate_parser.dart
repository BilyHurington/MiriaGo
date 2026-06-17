import 'package:latlong2/latlong.dart';

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

String _normalizeCoordinateText(String input) {
  return input
      .trim()
      .replaceAll('，', ',')
      .replaceAll('；', ';')
      .replaceAll(RegExp(r'\s+'), ' ');
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

LatLng? _parseDmsCoordinate(String input) {
  double? latitude;
  double? longitude;
  for (final directionMatch in RegExp(
    r'[NSEW]',
    caseSensitive: false,
  ).allMatches(input)) {
    final direction = directionMatch.group(0)!.toUpperCase();
    final value = _dmsValueAroundDirection(input, directionMatch, direction);
    if (value == null) {
      continue;
    }
    if (direction == 'N' || direction == 'S') {
      latitude = value;
    } else {
      longitude = value;
    }
  }

  return _validatedLatLng(latitude, longitude);
}

double? _dmsValueAroundDirection(
  String input,
  RegExpMatch directionMatch,
  String direction,
) {
  final directionStart = directionMatch.start;
  final directionEnd = directionMatch.end;
  final before = input.substring(0, directionStart);
  final after = input.substring(directionEnd);
  final previousDirection = before.lastIndexOf(
    RegExp('[NSEW]', caseSensitive: false),
  );
  final nextDirectionMatch = RegExp(
    '[NSEW]',
    caseSensitive: false,
  ).firstMatch(after);
  final nextDirection = nextDirectionMatch == null
      ? input.length
      : directionEnd + nextDirectionMatch.start;
  final beforeSegment = input.substring(
    previousDirection < 0 ? 0 : previousDirection + 1,
    directionStart,
  );
  final compactBefore = beforeSegment.trimRight();
  final isSuffixDirection =
      compactBefore.isNotEmpty && RegExp(r'[\d"”″秒]$').hasMatch(compactBefore);
  final hasNumbersBefore =
      isSuffixDirection && RegExp(r'\d').hasMatch(beforeSegment);
  final segmentStart = hasNumbersBefore
      ? (previousDirection < 0 ? 0 : previousDirection + 1)
      : directionEnd;
  final segmentEnd = hasNumbersBefore ? directionStart : nextDirection;
  final segment = input.substring(segmentStart, segmentEnd);
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

double _dmsValue({
  required String degrees,
  required String? minutes,
  required String? seconds,
  required String direction,
}) {
  final degreeValue = double.parse(degrees);
  final minuteValue = minutes == null ? 0.0 : double.parse(minutes);
  final secondValue = seconds == null ? 0.0 : double.parse(seconds);
  final sign = direction == 'S' || direction == 'W' ? -1.0 : 1.0;
  return sign * (degreeValue + minuteValue / 60 + secondValue / 3600);
}

LatLng? _validatedLatLng(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) {
    return null;
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return LatLng(latitude, longitude);
}
