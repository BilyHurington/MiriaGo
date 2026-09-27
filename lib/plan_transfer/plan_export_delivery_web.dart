import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../desktop/tauri_bridge.dart';
import 'plan_export_delivery_result.dart';

Future<PreparedPlanExportDestination?> preparePlanExportDestinationImpl({
  required String fileName,
  required String mimeType,
  required String extension,
}) async {
  if (isTauriLauncherAvailable) {
    final destination = await prepareDesktopExportDestination(
      fileName: fileName,
      mimeType: mimeType,
      extension: extension,
    );
    if (destination == null) {
      throw const PlanExportCanceledException();
    }
    return _TauriPreparedDestination(
      path: destination.path,
      extension: extension,
    );
  }
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
  if (isTauriLauncherAvailable) {
    final destination = await preparePlanExportDestinationImpl(
      fileName: fileName,
      mimeType: mimeType,
      extension: extension,
    );
    if (destination == null) {
      return const PlanExportDeliveryResult(PlanExportDeliveryAction.canceled);
    }
    return destination.save(bytes);
  }

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

class _TauriPreparedDestination implements PreparedPlanExportDestination {
  const _TauriPreparedDestination({
    required this.path,
    required this.extension,
  });

  final String path;
  final String extension;

  @override
  Future<PlanExportDeliveryResult> save(List<int> bytes) async {
    final result = await writeDesktopExportFile(
      path: path,
      extension: extension,
      dataBase64: base64Encode(bytes),
    );
    return PlanExportDeliveryResult(
      result.action == 'canceled'
          ? PlanExportDeliveryAction.canceled
          : PlanExportDeliveryAction.saved,
      path: result.path ?? path,
    );
  }
}
