import 'dart:typed_data';

class PreparedRecordImage {
  const PreparedRecordImage({required this.path, this.discard});

  final String path;
  // Only the allocator supplies cleanup, never a path received from a record.
  final Future<void> Function()? discard;
}

typedef ReferenceImagePreparer =
    Future<PreparedRecordImage> Function(Uint8List bytes);
