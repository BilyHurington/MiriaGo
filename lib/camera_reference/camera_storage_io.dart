import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> buildReferencePhotoPath() async {
  final directory = await getApplicationDocumentsDirectory();
  final photosDirectory = Directory('${directory.path}/reference_photos');
  if (!photosDirectory.existsSync()) {
    photosDirectory.createSync(recursive: true);
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '${photosDirectory.path}/capture_$timestamp.jpg';
}

Future<String> saveRecordImageBytes({
  required Uint8List bytes,
  required String prefix,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final recordsDirectory = Directory('${directory.path}/visit_record_images');
  if (!recordsDirectory.existsSync()) {
    recordsDirectory.createSync(recursive: true);
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final path = '${recordsDirectory.path}/${prefix}_$timestamp.jpg';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}
