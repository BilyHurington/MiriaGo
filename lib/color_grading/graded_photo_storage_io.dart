import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> saveGradedPhoto({
  required Uint8List bytes,
  required String recordId,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final gradedDir = Directory('${directory.path}/graded_photos');
  if (!gradedDir.existsSync()) {
    gradedDir.createSync(recursive: true);
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final path = '${gradedDir.path}/graded_${recordId}_$timestamp.jpg';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}
