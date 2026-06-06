import 'dart:io';

bool visitRecordLocalFileExists(String path) {
  return File(path).existsSync();
}

void deleteVisitRecordLocalFile(String path) {
  try {
    File(path).deleteSync();
  } catch (_) {}
}
