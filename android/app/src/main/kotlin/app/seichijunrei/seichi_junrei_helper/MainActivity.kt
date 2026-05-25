package app.seichijunrei.seichi_junrei_helper

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "seichi/native_camera_preview",
                NativeCameraPreviewFactory(this, flutterEngine.dartExecutor.binaryMessenger)
            )
    }
}
