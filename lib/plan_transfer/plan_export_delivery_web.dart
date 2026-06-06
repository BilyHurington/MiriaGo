import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:web/web.dart' as web;

import 'plan_export_delivery_result.dart';

Future<PreparedPlanExportDestination?> preparePlanExportDestinationImpl({
  required String fileName,
  required String mimeType,
  required String extension,
}) async {
  if (!globalContext.has('showSaveFilePicker')) {
    return null;
  }

  try {
    final handle = await _pickSaveFile(
      fileName: fileName,
      mimeType: mimeType,
      extension: extension,
    );
    return _WebFileSystemPreparedDestination(
      handle: handle,
      mimeType: mimeType,
    );
  } catch (error) {
    if (_isSaveCanceled(error)) {
      throw const PlanExportCanceledException();
    }
    rethrow;
  }
}

Future<PlanExportDeliveryResult> deliverPlanExportImpl({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
  required String shareSubject,
  required String shareText,
  required String extension,
}) async {
  if (globalContext.has('showSaveFilePicker')) {
    try {
      final handle = await _pickSaveFile(
        fileName: fileName,
        mimeType: mimeType,
        extension: extension,
      );
      return _WebFileSystemPreparedDestination(
        handle: handle,
        mimeType: mimeType,
      ).save(bytes);
    } catch (error) {
      if (_isSaveCanceled(error)) {
        return const PlanExportDeliveryResult(
          PlanExportDeliveryAction.canceled,
        );
      }
      rethrow;
    }
  }

  final location = await file_selector.getSaveLocation(
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
  if (location == null) {
    return const PlanExportDeliveryResult(PlanExportDeliveryAction.canceled);
  }

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

Future<web.FileSystemFileHandle> _pickSaveFile({
  required String fileName,
  required String mimeType,
  required String extension,
}) {
  return _showSaveFilePicker(
    _SaveFilePickerOptions(
      suggestedName: fileName,
      types: [
        _FilePickerAcceptType(
          description: 'MiriaGo data package',
          accept:
              {
                    mimeType: ['.$extension'],
                  }.jsify()!
                  as JSObject,
        ),
      ].toJS,
    ),
  ).toDart;
}

bool _isSaveCanceled(Object error) {
  try {
    return error.toString().contains('AbortError');
  } catch (_) {
    return false;
  }
}

@JS('showSaveFilePicker')
external JSPromise<web.FileSystemFileHandle> _showSaveFilePicker(
  _SaveFilePickerOptions options,
);

extension type _SaveFilePickerOptions._(JSObject _) implements JSObject {
  external factory _SaveFilePickerOptions({
    String suggestedName,
    JSArray<_FilePickerAcceptType> types,
  });
}

extension type _FilePickerAcceptType._(JSObject _) implements JSObject {
  external factory _FilePickerAcceptType({String description, JSObject accept});
}

class _WebFileSystemPreparedDestination
    implements PreparedPlanExportDestination {
  const _WebFileSystemPreparedDestination({
    required this.handle,
    required this.mimeType,
  });

  final web.FileSystemFileHandle handle;
  final String mimeType;

  @override
  Future<PlanExportDeliveryResult> save(List<int> bytes) async {
    final writable = await handle.createWritable().toDart;
    final blob = web.Blob(
      [Uint8List.fromList(bytes).toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    await writable.write(blob).toDart;
    await writable.close().toDart;
    return PlanExportDeliveryResult(PlanExportDeliveryAction.saved);
  }
}
