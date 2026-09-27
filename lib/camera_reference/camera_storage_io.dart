import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> _visitRecordImagesDirectory() async {
  final directory = await getApplicationDocumentsDirectory();
  final recordsDirectory = Directory('${directory.path}/visit_record_images');
  if (!recordsDirectory.existsSync()) {
    recordsDirectory.createSync(recursive: true);
  }
  return recordsDirectory;
}

Future<String> buildVisitRecordPhotoPath({String extension = 'jpg'}) async {
  final recordsDirectory = await _visitRecordImagesDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final normalizedExtension = extension.replaceFirst(RegExp(r'^\.+'), '');
  final safeExtension = normalizedExtension.isEmpty
      ? 'jpg'
      : normalizedExtension;
  return p.join(recordsDirectory.path, 'capture_$timestamp.$safeExtension');
}

Future<String> copyVisitRecordPhoto(String sourcePath) async {
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    throw FileSystemException('Visit photo source does not exist', sourcePath);
  }

  final extension = p.extension(sourcePath).replaceFirst('.', '');
  final targetPath = await buildVisitRecordPhotoPath(extension: extension);
  return sourceFile.copy(targetPath).then((file) => file.path);
}

Future<String> saveRecordImageBytes({
  required Uint8List bytes,
  required String prefix,
}) async {
  final recordsDirectory = await _visitRecordImagesDirectory();

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final path = p.join(recordsDirectory.path, '${prefix}_$timestamp.jpg');
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}
