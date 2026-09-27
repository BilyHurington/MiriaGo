import 'dart:typed_data';

/// Reads a local file (not available on the web).
Future<Uint8List?> readLocalViewerFile(String path) async => null;

/// Whether [path] is an existing local file.
bool localViewerFileExists(String path) => false;

/// Writes [bytes] to a temporary file for sharing / gallery saving.
Future<String?> writeTemporaryViewerImage(
  Uint8List bytes, {
  required String extension,
}) async => null;

/// Shares a local file through the system share sheet.
Future<void> shareViewerFile(String path) async {}
