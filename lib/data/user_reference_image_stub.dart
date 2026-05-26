class StoredUserReferenceImage {
  const StoredUserReferenceImage({
    required this.thumbnailPath,
    required this.fullImagePath,
  });

  final String thumbnailPath;
  final String fullImagePath;
}

Future<StoredUserReferenceImage?> storeUserReferenceImage({
  required String sourcePath,
  required String pointId,
}) async {
  return null;
}
