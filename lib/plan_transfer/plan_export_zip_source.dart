import 'dart:typed_data';

/// Where the content of one export ZIP entry comes from.
///
/// On native platforms image assets stay on disk ([filePath]) and are only
/// read by the ZIP worker isolate, one at a time, so photo bytes are neither
/// held by the UI isolate nor copied into the worker's spawn message. Small
/// generated files (JSON/CSV), and every entry on the web, carry [bytes].
class PlanExportZipSource {
  const PlanExportZipSource.bytes(Uint8List this.bytes) : filePath = null;

  const PlanExportZipSource.file(String this.filePath) : bytes = null;

  final Uint8List? bytes;
  final String? filePath;
}
