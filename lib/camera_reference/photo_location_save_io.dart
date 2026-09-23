import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_location.dart';
import 'visit_record_save_assets.dart';
import '../widgets/bounded_image.dart';

Future<void> retainPhotoPreviewUntilRead(
  String path,
  BuildContext context,
) async {
  // The confirmation panel uses this exact key and target. Completion includes
  // the bounded source read on both success and failure, before source cleanup.
  await precacheImage(
    BoundedImageProvider(path: path),
    context,
    onError: (_, _) {},
  );
}

Future<PreparedPhotoLocation> preparePhotoLocation({
  required String sourcePath,
  required PhotoLocationData location,
  required PhotoLocationWriter writer,
}) async {
  final documents = await getApplicationDocumentsDirectory();
  final root = Directory(p.join(documents.path, 'visit_record_images'));
  await root.create(recursive: true);
  final owned = await root.createTemp('location-');
  var retain = false;
  try {
    final copy = await File(sourcePath).copy(p.join(owned.path, 'photo.jpg'));
    bool written;
    try {
      written = await writer(copy.path, location);
    } catch (_) {
      written = false;
    }
    if (!written) {
      return PreparedPhotoLocation(path: sourcePath, written: false);
    }
    retain = true;
    return PreparedPhotoLocation(
      path: copy.path,
      written: true,
      discard: () async {
        if (await owned.exists()) await owned.delete(recursive: true);
      },
    );
  } finally {
    if (!retain) {
      await owned.delete(recursive: true);
    }
  }
}

Future<PreparedRecordImage> prepareReferenceImage(Uint8List bytes) async {
  final documents = await getApplicationDocumentsDirectory();
  final root = Directory(p.join(documents.path, 'visit_record_images'));
  await root.create(recursive: true);
  final owned = await root.createTemp('reference-');
  try {
    final file = await File(
      p.join(owned.path, 'reference.jpg'),
    ).writeAsBytes(bytes, flush: true);
    return PreparedRecordImage(
      path: file.path,
      discard: () async {
        if (await owned.exists()) await owned.delete(recursive: true);
      },
    );
  } catch (_) {
    await owned.delete(recursive: true);
    rethrow;
  }
}
