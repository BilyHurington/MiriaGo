import 'package:flutter/services.dart';

class IncomingPlanFileChannel {
  const IncomingPlanFileChannel();

  static const MethodChannel _channel = MethodChannel('seichi/plan_file');

  Future<String?> getInitialPath() {
    return _channel.invokeMethod<String>('getInitialPath');
  }

  void listen(void Function(String path) onPath) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openPath') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          onPath(path);
        }
      }
    });
  }
}
