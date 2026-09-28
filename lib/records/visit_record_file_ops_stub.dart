import '../data/pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';

bool visitRecordLocalFileExists(String path) {
  return false;
}

void deleteVisitRecordLocalFile(String path) {}

Future<void> deleteUnreferencedVisitRecordPhotos({
  required PilgrimageVisitRecord record,
  required PilgrimageRepository repository,
}) async {}
