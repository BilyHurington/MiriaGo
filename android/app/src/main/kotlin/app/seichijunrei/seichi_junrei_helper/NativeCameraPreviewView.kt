package app.seichijunrei.seichi_junrei_helper

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.view.MotionEvent
import android.view.View
import androidx.exifinterface.media.ExifInterface
import androidx.camera.core.AspectRatio
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
import kotlin.math.abs
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
    private var targetAspectRatio = 1.0

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
            "initialize" -> initialize(call, result)
            "getZoomState" -> result.success(zoomStateMap())
            "setZoomRatio" -> setZoomRatio(call, result)
            "setTargetAspectRatio" -> setTargetAspectRatio(call, result)
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

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        targetAspectRatio = sanitizedAspectRatio(
            call.argument<Double>("targetAspectRatio") ?: targetAspectRatio,
        )
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
            .setTargetAspectRatio(cameraTargetAspectRatio())
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

    private fun setTargetAspectRatio(call: MethodCall, result: MethodChannel.Result) {
        targetAspectRatio = sanitizedAspectRatio(
            call.argument<Double>("targetAspectRatio") ?: targetAspectRatio,
        )
        try {
            if (cameraProvider != null) {
                bindCamera()
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("camera_ratio_failed", error.message, null)
        }
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
                    try {
                        cropImageToTargetAspectRatio(file)
                        activity.runOnUiThread { result.success(file.absolutePath) }
                    } catch (error: Exception) {
                        activity.runOnUiThread {
                            result.error("capture_crop_failed", error.message, null)
                        }
                    }
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

    private fun sanitizedAspectRatio(value: Double): Double {
        return value.coerceIn(0.2, 5.0)
    }

    private fun cameraTargetAspectRatio(): Int {
        val normalized = if (targetAspectRatio >= 1.0) targetAspectRatio else 1.0 / targetAspectRatio
        return if (abs(normalized - 16.0 / 9.0) < abs(normalized - 4.0 / 3.0)) {
            AspectRatio.RATIO_16_9
        } else {
            AspectRatio.RATIO_4_3
        }
    }

    private fun cropImageToTargetAspectRatio(file: File) {
        var bitmap = BitmapFactory.decodeFile(file.absolutePath) ?: return

        val exif = ExifInterface(file.absolutePath)
        val orientation = exif.getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
        }
        if (!matrix.isIdentity) {
            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotated != bitmap) bitmap.recycle()
            bitmap = rotated
        }

        val currentRatio = bitmap.width.toDouble() / bitmap.height.toDouble()
        if (abs(currentRatio - targetAspectRatio) < 0.01) {
            bitmap.recycle()
            return
        }

        val cropWidth: Int
        val cropHeight: Int
        if (currentRatio > targetAspectRatio) {
            cropHeight = bitmap.height
            cropWidth = (cropHeight * targetAspectRatio).toInt().coerceIn(1, bitmap.width)
        } else {
            cropWidth = bitmap.width
            cropHeight = (cropWidth / targetAspectRatio).toInt().coerceIn(1, bitmap.height)
        }

        val left = ((bitmap.width - cropWidth) / 2).coerceAtLeast(0)
        val top = ((bitmap.height - cropHeight) / 2).coerceAtLeast(0)
        val cropped = Bitmap.createBitmap(bitmap, left, top, cropWidth, cropHeight)
        file.outputStream().use { output ->
            cropped.compress(Bitmap.CompressFormat.JPEG, 95, output)
        }
        if (cropped != bitmap) {
            cropped.recycle()
        }
        bitmap.recycle()
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
