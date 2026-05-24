import 'dart:typed_data';

Future<String> buildReferencePhotoPath() async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return 'capture_$timestamp.jpg';
}

Future<String> saveRecordImageBytes({
  required Uint8List bytes,
  required String prefix,
}) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '${prefix}_$timestamp.jpg';
}
