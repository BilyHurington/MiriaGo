package app.miriago.miriago

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var planFileChannel: MethodChannel? = null
    private var pendingPlanPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "seichi/native_camera_preview",
                NativeCameraPreviewFactory(this, flutterEngine.dartExecutor.binaryMessenger)
            )

        val galleryChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seichi/gallery_saver"
        )
        val cameraCapabilitiesChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seichi/camera_capabilities"
        )
        planFileChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seichi/plan_file"
        )

        pendingPlanPath = extractPlanPathFromIntent(intent)
        planFileChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialPath") {
                result.success(pendingPlanPath)
                pendingPlanPath = null
            } else {
                result.notImplemented()
            }
        }

        galleryChannel.setMethodCallHandler { call, result ->
            if (call.method == "saveToGallery") {
                val filePath = call.argument<String>("filePath")
                if (filePath == null) {
                    result.error("INVALID_ARGUMENT", "filePath is required", null)
                    return@setMethodCallHandler
                }
                try {
                    val savedPath = saveImageToGallery(filePath)
                    result.success(savedPath)
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        cameraCapabilitiesChannel.setMethodCallHandler { call, result ->
            if (call.method == "getBackCameraZoomRange") {
                getBackCameraZoomRange(result)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val path = extractPlanPathFromIntent(intent) ?: return
        pendingPlanPath = path
        planFileChannel?.invokeMethod("openPath", path)
    }

    private fun saveImageToGallery(sourcePath: String): String? {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) return null

        val extension = sourceFile.extension.ifEmpty { "jpg" }
        val mimeType = when (extension.lowercase()) {
            "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"
            else -> "image/jpeg"
        }

        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "seichi_${sourceFile.name}")
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.IS_PENDING, 1)
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/SeichiJunrei")
            }
        }

        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: return null

        resolver.openOutputStream(uri)?.use { output ->
            sourceFile.inputStream().use { input ->
                input.copyTo(output)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }

        return uri.toString()
    }

    private fun getBackCameraZoomRange(result: MethodChannel.Result) {
        try {
            val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            for (cameraId in manager.cameraIdList) {
                val characteristics = manager.getCameraCharacteristics(cameraId)
                if (
                    characteristics.get(CameraCharacteristics.LENS_FACING) !=
                    CameraCharacteristics.LENS_FACING_BACK
                ) {
                    continue
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val range = characteristics.get(
                        CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE
                    )
                    if (range != null) {
                        result.success(
                            mapOf(
                                "minZoomRatio" to range.lower.toDouble(),
                                "maxZoomRatio" to range.upper.toDouble(),
                            )
                        )
                        return
                    }
                }

                val maxDigitalZoom = characteristics.get(
                    CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM
                ) ?: 1.0f
                result.success(
                    mapOf(
                        "minZoomRatio" to 1.0,
                        "maxZoomRatio" to maxDigitalZoom.toDouble(),
                    )
                )
                return
            }
            result.success(mapOf("minZoomRatio" to 1.0, "maxZoomRatio" to 20.0))
        } catch (error: Exception) {
            result.error("camera_capabilities_failed", error.message, null)
        }
    }

    private fun extractPlanPathFromIntent(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val uri = intent.data ?: return null
        return try {
            copyPlanUriToCache(uri)
        } catch (_: Exception) {
            null
        }
    }

    private fun copyPlanUriToCache(uri: Uri): String? {
        val directory = File(cacheDir, "incoming_plans")
        if (!directory.exists()) {
            directory.mkdirs()
        }
        val file = File(directory, "incoming_${System.currentTimeMillis()}.sjhplan")
        val input = when (uri.scheme) {
            "content" -> contentResolver.openInputStream(uri)
            "file" -> File(uri.path ?: return null).inputStream()
            else -> null
        } ?: return null

        input.use { source ->
            file.outputStream().use { output ->
                source.copyTo(output)
            }
        }
        return file.absolutePath
    }
}
