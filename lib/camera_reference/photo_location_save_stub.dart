import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'photo_location.dart';
import 'visit_record_save_assets.dart';
import '../widgets/bounded_image.dart';

Future<void> retainPhotoPreviewUntilRead(
  String path,
  BuildContext context,
) async {
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
}) async => PreparedPhotoLocation(path: sourcePath, written: false);

Future<PreparedRecordImage> prepareReferenceImage(Uint8List bytes) async {
  throw UnsupportedError('Reference image storage is unavailable');
}
