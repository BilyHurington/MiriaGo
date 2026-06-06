import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'plan_export_delivery_result.dart';

Future<PreparedPlanExportDestination?> preparePlanExportDestinationImpl({
  required String fileName,
  required String mimeType,
  required String extension,
}) async {
  return null;
}

Future<PlanExportDeliveryResult> deliverPlanExportImpl({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
  required String shareSubject,
  required String shareText,
  required String extension,
}) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return const PlanExportDeliveryResult(PlanExportDeliveryAction.saved);
}
