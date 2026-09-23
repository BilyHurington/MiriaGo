import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'photo_location.dart';
import 'visit_record_save_assets.dart';

Future<void> retainPhotoPreviewUntilRead(
  String path,
  BuildContext context,
) async {}

Future<PreparedPhotoLocation> preparePhotoLocation({
  required String sourcePath,
  required PhotoLocationData location,
  required PhotoLocationWriter writer,
}) async => PreparedPhotoLocation(path: sourcePath, written: false);

Future<PreparedRecordImage> prepareReferenceImage(Uint8List bytes) async {
  throw UnsupportedError('Reference image storage is unavailable');
}
