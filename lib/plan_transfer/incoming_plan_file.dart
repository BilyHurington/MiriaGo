import 'package:flutter/services.dart';

import 'plan_import_package.dart';

/// Native failure while copying a plan file handed to the app by another app.
class IncomingPlanFileException implements Exception {
  const IncomingPlanFileException(this.code, [this.message]);

  static const tooLargeCode = 'PLAN_FILE_TOO_LARGE';

  final String code;
  final String? message;

  bool get isTooLarge => code == tooLargeCode;

  /// User-facing text, worded like [PlanImportLimitException].
  String get userMessage => isTooLarge
      ? '导入超限：计划文件超过 '
            '${const PlanImportLimits().maxCompressedBytes ~/ (1024 * 1024)} MiB '
            '上限。请拆分计划或减少打包图片后重试。'
      : '计划文件导入失败';

  @override
  String toString() => 'IncomingPlanFileException($code, $message)';
}

class IncomingPlanFileChannel {
  const IncomingPlanFileChannel();

  static const MethodChannel _channel = MethodChannel('seichi/plan_file');

  Future<String?> getInitialPath() async {
    try {
      return await _channel.invokeMethod<String>('getInitialPath');
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      throw IncomingPlanFileException(error.code, error.message);
    }
  }

  void listen(
    void Function(String path) onPath, {
    void Function(IncomingPlanFileException error)? onError,
  }) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openPath') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          onPath(path);
        }
      } else if (call.method == 'openPathFailed') {
        final arguments = call.arguments;
        final code = arguments is Map ? arguments['code'] : null;
        final message = arguments is Map ? arguments['message'] : null;
        onError?.call(
          IncomingPlanFileException(
            code is String ? code : 'COPY_FAILED',
            message is String ? message : null,
          ),
        );
      }
    });
  }

  /// Deletes the native temporary copy once it has been read. The native side
  /// only removes files inside its own incoming-plan directory.
  Future<void> release(String path) async {
    try {
      await _channel.invokeMethod<void>('releasePath', path);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
