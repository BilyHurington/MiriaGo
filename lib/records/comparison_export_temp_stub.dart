import '../data/pilgrimage_repository.dart';

// Web/desktop exports go to a browser download or a user-chosen save location,
// never to an app-owned temporary file, so there is nothing to clean up.
Future<void> deleteComparisonExportTemp(String? path) async {}

Future<void> sweepStaleComparisonExports({
  required PilgrimageRepository repository,
  Duration maxAge = const Duration(days: 1),
  DateTime? now,
}) async {}
