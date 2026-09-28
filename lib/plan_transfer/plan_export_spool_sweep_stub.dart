/// Web and desktop keep export assets in memory; nothing to sweep.
Future<void> sweepStaleExportSpools({
  Duration maxAge = const Duration(hours: 1),
}) async {}
