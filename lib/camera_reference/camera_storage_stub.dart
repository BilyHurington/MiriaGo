import 'dart:typed_data';

Future<String> buildVisitRecordPhotoPath({String extension = 'jpg'}) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final safeExtension = extension.replaceFirst(RegExp(r'^\.+'), '');
  return 'capture_$timestamp.${safeExtension.isEmpty ? 'jpg' : safeExtension}';
}

Future<String> copyVisitRecordPhoto(String sourcePath) async {
  final parts = sourcePath.split('.');
  final extension = parts.length > 1 ? parts.last : 'jpg';
  return buildVisitRecordPhotoPath(extension: extension);
}

Future<String> saveRecordImageBytes({
  required Uint8List bytes,
  required String prefix,
}) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '${prefix}_$timestamp.jpg';
}
