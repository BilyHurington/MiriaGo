import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import 'plan_export_delivery_result.dart';

Future<PreparedPlanExportDestination?> preparePlanExportDestinationImpl({
  required String fileName,
  required String mimeType,
  required String extension,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return null;
  }

  final location = await _getSaveLocation(
    fileName: fileName,
    mimeType: mimeType,
    extension: extension,
  );
  if (location == null) {
    throw const PlanExportCanceledException();
  }
  return _FileSelectorPreparedDestination(
    location: location,
    fileName: fileName,
    mimeType: mimeType,
  );
}

Future<PlanExportDeliveryResult> deliverPlanExportImpl({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
  required String shareSubject,
  required String shareText,
  required String extension,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await share_plus.Share.shareXFiles(
      [share_plus.XFile(file.path, mimeType: mimeType, name: fileName)],
      subject: shareSubject,
      sharePositionOrigin: _mobileSharePositionOrigin(),
      fileNameOverrides: [fileName],
    );
    return PlanExportDeliveryResult(
      PlanExportDeliveryAction.shared,
      path: file.path,
    );
  }

  final location = await _getSaveLocation(
    fileName: fileName,
    mimeType: mimeType,
    extension: extension,
  );
  if (location == null) {
    return const PlanExportDeliveryResult(PlanExportDeliveryAction.canceled);
  }

  return _FileSelectorPreparedDestination(
    location: location,
    fileName: fileName,
    mimeType: mimeType,
  ).save(bytes);
}

Future<file_selector.FileSaveLocation?> _getSaveLocation({
  required String fileName,
  required String mimeType,
  required String extension,
}) {
  return file_selector.getSaveLocation(
    acceptedTypeGroups: [
      file_selector.XTypeGroup(
        label: 'MiriaGo data package',
        extensions: [extension],
        mimeTypes: [mimeType],
      ),
    ],
    suggestedName: fileName,
    confirmButtonText: '保存',
  );
}

class _FileSelectorPreparedDestination
    implements PreparedPlanExportDestination {
  const _FileSelectorPreparedDestination({
    required this.location,
    required this.fileName,
    required this.mimeType,
  });

  final file_selector.FileSaveLocation location;
  final String fileName;
  final String mimeType;

  @override
  Future<PlanExportDeliveryResult> save(List<int> bytes) async {
    final file = file_selector.XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: mimeType,
      name: fileName,
    );
    await file.saveTo(location.path);
    return PlanExportDeliveryResult(
      PlanExportDeliveryAction.saved,
      path: location.path,
    );
  }
}

Rect _mobileSharePositionOrigin() {
  final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
  final size = view == null
      ? const Size(1, 1)
      : view.physicalSize / view.devicePixelRatio;
  return Offset.zero & size;
}
