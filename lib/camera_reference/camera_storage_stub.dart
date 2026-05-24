Future<String> buildReferencePhotoPath() async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return 'capture_$timestamp.jpg';
}
