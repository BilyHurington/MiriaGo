package app.seichijunrei.seichi_junrei_helper

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.view.MotionEvent
import android.view.View
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

class NativeCameraPreviewView(
    private val activity: MainActivity,
    private val context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val previewView = PreviewView(context)
    private val channel = MethodChannel(messenger, "seichi/native_camera_preview_$viewId")
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var imageCapture: ImageCapture? = null
    private var lensFacing = CameraSelector.LENS_FACING_BACK
    private var flashMode = ImageCapture.FLASH_MODE_AUTO

    init {
        previewView.scaleType = PreviewView.ScaleType.FIT_CENTER
        previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        previewView.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_UP) {
                focusAt(event.x, event.y)
            }
            true
        }
        channel.setMethodCallHandler(this)
    }

    override fun getView(): View = previewView

    override fun dispose() {
        channel.setMethodCallHandler(null)
        cameraProvider?.unbindAll()
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(result)
            "getZoomState" -> result.success(zoomStateMap())
            "setZoomRatio" -> setZoomRatio(call, result)
            "setFlashMode" -> setFlashMode(call, result)
            "switchCamera" -> switchCamera(result)
            "takePicture" -> takePicture(result)
            "dispose" -> {
                dispose()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun initialize(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            result.error("camera_permission_denied", "Camera permission is not granted.", null)
            return
        }

        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener(
            {
                try {
                    cameraProvider = providerFuture.get()
                    bindCamera()
                    camera?.cameraControl?.setZoomRatio(1.0f)
                    result.success(zoomStateMap())
                } catch (error: Exception) {
                    result.error("camera_initialize_failed", error.message, null)
                }
            },
            ContextCompat.getMainExecutor(context),
        )
    }

    private fun bindCamera() {
        val provider = cameraProvider ?: return
        val selector = CameraSelector.Builder()
            .requireLensFacing(lensFacing)
            .build()
        val preview = Preview.Builder().build().also {
            it.setSurfaceProvider(previewView.surfaceProvider)
        }
        imageCapture = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
            .setFlashMode(flashMode)
            .build()

        provider.unbindAll()
        camera = provider.bindToLifecycle(
            activity as LifecycleOwner,
            selector,
            preview,
            imageCapture,
        )
    }

    private fun setZoomRatio(call: MethodCall, result: MethodChannel.Result) {
        val requested = (call.argument<Double>("zoomRatio") ?: 1.0).toFloat()
        val state = camera?.cameraInfo?.zoomState?.value
        val minZoom = state?.minZoomRatio ?: 1.0f
        val maxZoom = state?.maxZoomRatio ?: 1.0f
        val nextZoom = min(max(requested, minZoom), maxZoom)
        camera?.cameraControl?.setZoomRatio(nextZoom)
        result.success(zoomStateMap(nextZoom))
    }

    private fun setFlashMode(call: MethodCall, result: MethodChannel.Result) {
        when (call.argument<String>("flashMode") ?: "auto") {
            "off" -> {
                flashMode = ImageCapture.FLASH_MODE_OFF
                camera?.cameraControl?.enableTorch(false)
            }
            "on" -> {
                flashMode = ImageCapture.FLASH_MODE_ON
                camera?.cameraControl?.enableTorch(false)
            }
            "torch" -> {
                flashMode = ImageCapture.FLASH_MODE_OFF
                camera?.cameraControl?.enableTorch(true)
            }
            else -> {
                flashMode = ImageCapture.FLASH_MODE_AUTO
                camera?.cameraControl?.enableTorch(false)
            }
        }
        imageCapture?.flashMode = flashMode
        result.success(zoomStateMap())
    }

    private fun switchCamera(result: MethodChannel.Result) {
        lensFacing = if (lensFacing == CameraSelector.LENS_FACING_BACK) {
            CameraSelector.LENS_FACING_FRONT
        } else {
            CameraSelector.LENS_FACING_BACK
        }

        try {
            bindCamera()
            result.success(zoomStateMap())
        } catch (error: Exception) {
            lensFacing = CameraSelector.LENS_FACING_BACK
            bindCamera()
            result.error("camera_switch_failed", error.message, null)
        }
    }

    private fun takePicture(result: MethodChannel.Result) {
        val capture = imageCapture
        if (capture == null) {
            result.error("camera_not_ready", "Camera is not ready.", null)
            return
        }

        val directory = File(context.filesDir, "visit_record_images")
        if (!directory.exists()) {
            directory.mkdirs()
        }
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(Date())
        val file = File(directory, "native_camera_$timestamp.jpg")
        val outputOptions = ImageCapture.OutputFileOptions.Builder(file).build()
        capture.takePicture(
            outputOptions,
            executor,
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                    activity.runOnUiThread { result.success(file.absolutePath) }
                }

                override fun onError(exception: ImageCaptureException) {
                    activity.runOnUiThread {
                        result.error("capture_failed", exception.message, null)
                    }
                }
            },
        )
    }

    private fun focusAt(x: Float, y: Float) {
        val currentCamera = camera ?: return
        val point = previewView.meteringPointFactory.createPoint(x, y)
        val action = FocusMeteringAction.Builder(point, FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE)
            .setAutoCancelDuration(3, java.util.concurrent.TimeUnit.SECONDS)
            .build()
        currentCamera.cameraControl.startFocusAndMetering(action)
    }

    private fun zoomStateMap(overrideZoom: Float? = null): Map<String, Any> {
        val state = camera?.cameraInfo?.zoomState?.value
        val minZoom = state?.minZoomRatio ?: 1.0f
        val maxZoom = state?.maxZoomRatio ?: 1.0f
        val zoom = overrideZoom ?: state?.zoomRatio ?: 1.0f
        return mapOf(
            "minZoomRatio" to minZoom.toDouble(),
            "maxZoomRatio" to maxZoom.toDouble(),
            "zoomRatio" to zoom.toDouble(),
            "lensFacing" to if (lensFacing == CameraSelector.LENS_FACING_BACK) "back" else "front",
        )
    }
}
