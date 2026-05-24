import 'dart:io';

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
