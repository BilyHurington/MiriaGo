package app.miriago.miriago

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.display.DisplayManager
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.Surface
import android.view.View
import androidx.camera.core.AspectRatio
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executor
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

private enum class NativeLensMode(val value: String) {
    BackAuto("backAuto"),
    BackTelephoto("backTelephoto"),
    Front("front"),
}

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
    private var preview: Preview? = null
    private var imageCapture: ImageCapture? = null
    private var torchEnabled = false
    private var disposed = false
    private var lensMode = NativeLensMode.BackAuto
    private val telephotoCameraId: String? by lazy { findTelephotoCameraId() }
    private var flashMode = ImageCapture.FLASH_MODE_AUTO
    private var targetAspectRatio = 1.0
    private var cropCaptureToAspectRatio = true
    // Captures whose MethodChannel reply is still outstanding; dispose()
    // fails them so the Dart shutter never waits forever.
    private val pendingCaptures = mutableSetOf<CaptureReply>()
    private val displayManager =
        context.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager

    // MainActivity handles orientation config changes itself and the view is
    // kept across rotations, so CameraX use cases must follow the display
    // rotation explicitly (their rotation is otherwise fixed at build time).
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = Unit
        override fun onDisplayRemoved(displayId: Int) = Unit
        override fun onDisplayChanged(displayId: Int) {
            updateTargetRotation()
        }
    }

    init {
        previewView.scaleType = PreviewView.ScaleType.FILL_CENTER
        previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        previewView.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_UP) {
                focusAt(event.x, event.y)
            }
            true
        }
        channel.setMethodCallHandler(this)
        displayManager?.registerDisplayListener(
            displayListener,
            Handler(Looper.getMainLooper()),
        )
    }

    override fun getView(): View = previewView

    override fun dispose() {
        if (disposed) return
        disposed = true
        displayManager?.unregisterDisplayListener(displayListener)
        channel.setMethodCallHandler(null)
        // CameraX delivers capture callbacks on `executor`; once it is shut
        // down they are rejected, so answer every pending capture here.
        val pending = pendingCaptures.toList()
        pendingCaptures.clear()
        for (reply in pending) {
            reply.error("camera_disposed", "Camera preview was disposed.")
        }
        // Release only this view's use cases: a replacement preview view may
        // already have bound the shared process camera provider.
        val ownUseCases = listOfNotNull(preview, imageCapture)
        if (ownUseCases.isNotEmpty()) {
            cameraProvider?.unbind(*ownUseCases.toTypedArray())
        }
        camera = null
        preview = null
        imageCapture = null
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "getZoomState" -> result.success(zoomStateMap())
            "setZoomRatio" -> setZoomRatio(call, result)
            "setTargetAspectRatio" -> setTargetAspectRatio(call, result)
            "setCropCaptureToAspectRatio" -> setCropCaptureToAspectRatio(call, result)
            "setFlashMode" -> setFlashMode(call, result)
            "switchCamera" -> switchCamera(result)
            "switchLens" -> switchLens(result)
            "takePicture" -> takePicture(call, result)
            "writePhotoLocation" -> writePhotoLocation(call, result)
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
                if (disposed) {
                    result.error("camera_disposed", "Camera preview was disposed.", null)
                    return@addListener
                }
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
        if (disposed) return
        val provider = cameraProvider ?: return
        val selector = cameraSelectorForLensMode(lensMode)
        val rotation = currentDisplayRotation()
        val nextPreview = Preview.Builder()
            .setTargetAspectRatio(cameraTargetAspectRatio())
            .setTargetRotation(rotation)
            .build()
            .also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }
        val nextCapture = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
            .setTargetAspectRatio(cameraTargetAspectRatio())
            .setFlashMode(flashMode)
            .setTargetRotation(rotation)
            .build()
        preview = nextPreview
        imageCapture = nextCapture

        provider.unbindAll()
        camera = provider.bindToLifecycle(
            activity as LifecycleOwner,
            selector,
            nextPreview,
            nextCapture,
        )
        // Rebinding (ratio or lens change) resets the torch.
        if (torchEnabled) {
            camera?.cameraControl?.enableTorch(true)
        }
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

    private fun setCropCaptureToAspectRatio(call: MethodCall, result: MethodChannel.Result) {
        cropCaptureToAspectRatio = call.argument<Boolean>("enabled") ?: cropCaptureToAspectRatio
        result.success(null)
    }

    private fun setFlashMode(call: MethodCall, result: MethodChannel.Result) {
        when (call.argument<String>("flashMode") ?: "auto") {
            "off" -> {
                flashMode = ImageCapture.FLASH_MODE_OFF
                torchEnabled = false
            }
            "on" -> {
                flashMode = ImageCapture.FLASH_MODE_ON
                torchEnabled = false
            }
            "torch" -> {
                flashMode = ImageCapture.FLASH_MODE_OFF
                torchEnabled = true
            }
            else -> {
                flashMode = ImageCapture.FLASH_MODE_AUTO
                torchEnabled = false
            }
        }
        camera?.cameraControl?.enableTorch(torchEnabled)
        imageCapture?.flashMode = flashMode
        result.success(zoomStateMap())
    }

    private fun switchCamera(result: MethodChannel.Result) {
        switchLens(result)
    }

    private fun switchLens(result: MethodChannel.Result) {
        val previousMode = lensMode
        lensMode = nextLensMode()
        try {
            bindCamera()
            result.success(zoomStateMap())
        } catch (error: Exception) {
            lensMode = NativeLensMode.BackAuto
            try {
                bindCamera()
            } catch (_: Exception) {
                lensMode = previousMode
            }
            result.error("camera_switch_failed", error.message, null)
        }
    }

    private fun takePicture(call: MethodCall, result: MethodChannel.Result) {
        val capture = imageCapture
        if (capture == null) {
            result.error("camera_not_ready", "Camera is not ready.", null)
            return
        }
        // The saved JPEG's EXIF orientation comes from targetRotation, which
        // normalizeAndCropImage then applies before cropping.
        updateTargetRotation()
        val reply = CaptureReply(result)
        pendingCaptures.add(reply)

        val directory = File(context.filesDir, "visit_record_images")
        if (!directory.exists()) {
            directory.mkdirs()
        }
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(Date())
        val file = File(directory, "native_camera_$timestamp.jpg")
        val location = locationFromCall(call)
        val metadata = ImageCapture.Metadata().apply {
            this.location = location
        }
        val outputOptions = ImageCapture.OutputFileOptions.Builder(file)
            .setMetadata(metadata)
            .build()
        try {
            capture.takePicture(
                outputOptions,
                executor,
                object : ImageCapture.OnImageSavedCallback {
                    override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                        try {
                            normalizeAndCropImage(file, location)
                            if (!reply.success(file.absolutePath)) {
                                // Already failed as camera_disposed; nobody
                                // will pick this photo up.
                                file.delete()
                            }
                        } catch (error: Exception) {
                            reply.error("capture_crop_failed", error.message)
                        }
                    }

                    override fun onError(exception: ImageCaptureException) {
                        reply.error("capture_failed", exception.message)
                    }
                },
            )
        } catch (error: Exception) {
            reply.error("capture_failed", error.message)
        }
    }

    private fun updateTargetRotation() {
        if (disposed) return
        val rotation = currentDisplayRotation()
        imageCapture?.targetRotation = rotation
        preview?.targetRotation = rotation
    }

    @Suppress("DEPRECATION")
    private fun currentDisplayRotation(): Int {
        previewView.display?.rotation?.let { return it }
        return try {
            val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                activity.display
            } else {
                activity.windowManager.defaultDisplay
            }
            display?.rotation ?: Surface.ROTATION_0
        } catch (_: Exception) {
            Surface.ROTATION_0
        }
    }

    /**
     * Replies to a capture call exactly once, always on the main thread, and
     * drops it from [pendingCaptures] when it completes.
     */
    private inner class CaptureReply(private val result: MethodChannel.Result) {
        private val replied = AtomicBoolean(false)

        /** Returns false when the call was already answered. */
        fun success(path: String): Boolean {
            if (!replied.compareAndSet(false, true)) return false
            activity.runOnUiThread {
                pendingCaptures.remove(this)
                result.success(path)
            }
            return true
        }

        fun error(code: String, message: String?) {
            if (!replied.compareAndSet(false, true)) return
            activity.runOnUiThread {
                pendingCaptures.remove(this)
                result.error(code, message, null)
            }
        }
    }

    private fun writePhotoLocation(call: MethodCall, result: MethodChannel.Result) {
        writePhotoLocationCall(call, result, activity, executor)
    }

    private fun locationFromCall(call: MethodCall): Location? = photoLocationFromCall(call)

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

    private fun cameraSelectorForLensMode(mode: NativeLensMode): CameraSelector {
        val builder = CameraSelector.Builder()
        when (mode) {
            NativeLensMode.BackTelephoto -> {
                val cameraId = telephotoCameraId
                if (cameraId != null) {
                    builder.addCameraFilter { cameraInfos ->
                        cameraInfos.filter { Camera2CameraInfo.from(it).cameraId == cameraId }
                    }
                    return builder.build()
                }
                lensMode = NativeLensMode.BackAuto
                builder.requireLensFacing(CameraSelector.LENS_FACING_BACK)
            }
            NativeLensMode.Front -> builder.requireLensFacing(CameraSelector.LENS_FACING_FRONT)
            NativeLensMode.BackAuto -> builder.requireLensFacing(CameraSelector.LENS_FACING_BACK)
        }
        return builder.build()
    }

    private fun nextLensMode(): NativeLensMode {
        return when (lensMode) {
            NativeLensMode.BackAuto -> {
                if (telephotoCameraId != null) NativeLensMode.BackTelephoto else NativeLensMode.Front
            }
            NativeLensMode.BackTelephoto -> NativeLensMode.Front
            NativeLensMode.Front -> NativeLensMode.BackAuto
        }
    }

    private fun findTelephotoCameraId(): String? {
        return try {
            val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val backCameras = manager.cameraIdList.mapNotNull { cameraId ->
                val characteristics = manager.getCameraCharacteristics(cameraId)
                if (
                    characteristics.get(CameraCharacteristics.LENS_FACING) !=
                    CameraCharacteristics.LENS_FACING_BACK
                ) {
                    return@mapNotNull null
                }

                val focalLength = characteristics
                    .get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                    ?.maxOrNull() ?: return@mapNotNull null
                val physicalIds = physicalCameraIds(characteristics)
                CameraInfo(cameraId, focalLength, physicalIds)
            }
            val logicalCameraIds = backCameras
                .filter { it.physicalIds.isNotEmpty() }
                .map { it.cameraId }
                .toSet()
            val mainFocalLength = backCameras
                .filter { it.physicalIds.isNotEmpty() }
                .maxOfOrNull { it.focalLength }
                ?: backCameras.maxOfOrNull { it.focalLength }
                ?: return null
            backCameras
                .filter { it.cameraId !in logicalCameraIds }
                .filter { it.physicalIds.isEmpty() }
                .filter { it.focalLength > mainFocalLength * 1.25f }
                .maxByOrNull { it.focalLength }
                ?.cameraId
        } catch (_: Exception) {
            null
        }
    }

    private fun physicalCameraIds(characteristics: CameraCharacteristics): Set<String> {
        return try {
            characteristics.physicalCameraIds
        } catch (_: Exception) {
            emptySet()
        }
    }

    private fun normalizeAndCropImage(file: File, location: Location?) {
        val sourceExif = ExifInterface(file.absolutePath)
        val preservedAttributes = preservedExifTags.mapNotNull { tag ->
            sourceExif.getAttribute(tag)?.let { tag to it }
        }
        val bitmap = BitmapFactory.decodeFile(file.absolutePath) ?: return
        val oriented = applyExifOrientation(bitmap, file)
        val output = if (cropCaptureToAspectRatio) {
            cropBitmapToTargetAspectRatio(oriented)
        } else {
            oriented
        }

        file.outputStream().use { stream ->
            output.compress(Bitmap.CompressFormat.JPEG, 95, stream)
        }
        ExifInterface(file.absolutePath).apply {
            for ((tag, value) in preservedAttributes) {
                setAttribute(tag, value)
            }
            setAttribute(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL.toString(),
            )
            setAttribute(ExifInterface.TAG_IMAGE_WIDTH, output.width.toString())
            setAttribute(ExifInterface.TAG_IMAGE_LENGTH, output.height.toString())
            setAttribute(ExifInterface.TAG_PIXEL_X_DIMENSION, output.width.toString())
            setAttribute(ExifInterface.TAG_PIXEL_Y_DIMENSION, output.height.toString())
            setAttribute(ExifInterface.TAG_SOFTWARE, "MiriaGo")
            if (location != null) {
                setGpsInfo(location)
            }
            saveAttributes()
        }
        if (output != oriented) {
            output.recycle()
        }
        if (oriented != bitmap) {
            oriented.recycle()
        }
        bitmap.recycle()
    }

    private val preservedExifTags = listOf(
        ExifInterface.TAG_DATETIME,
        ExifInterface.TAG_DATETIME_ORIGINAL,
        ExifInterface.TAG_DATETIME_DIGITIZED,
        ExifInterface.TAG_SUBSEC_TIME,
        ExifInterface.TAG_SUBSEC_TIME_ORIGINAL,
        ExifInterface.TAG_SUBSEC_TIME_DIGITIZED,
        ExifInterface.TAG_OFFSET_TIME,
        ExifInterface.TAG_OFFSET_TIME_ORIGINAL,
        ExifInterface.TAG_OFFSET_TIME_DIGITIZED,
        ExifInterface.TAG_MAKE,
        ExifInterface.TAG_MODEL,
        ExifInterface.TAG_LENS_MODEL,
        ExifInterface.TAG_FOCAL_LENGTH,
        ExifInterface.TAG_F_NUMBER,
        ExifInterface.TAG_APERTURE_VALUE,
        ExifInterface.TAG_EXPOSURE_TIME,
        ExifInterface.TAG_SHUTTER_SPEED_VALUE,
        ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY,
        ExifInterface.TAG_FLASH,
        ExifInterface.TAG_WHITE_BALANCE,
        ExifInterface.TAG_EXPOSURE_BIAS_VALUE,
        ExifInterface.TAG_EXPOSURE_MODE,
        ExifInterface.TAG_METERING_MODE,
        ExifInterface.TAG_COLOR_SPACE,
    )

    private fun applyExifOrientation(bitmap: Bitmap, file: File): Bitmap {
        val orientation = ExifInterface(file.absolutePath).getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.preScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.preScale(-1f, 1f)
                matrix.postRotate(90f)
            }
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.preScale(-1f, 1f)
                matrix.postRotate(270f)
            }
            else -> return bitmap
        }

        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun cropBitmapToTargetAspectRatio(bitmap: Bitmap): Bitmap {
        val currentRatio = bitmap.width.toDouble() / bitmap.height.toDouble()
        if (abs(currentRatio - targetAspectRatio) < 0.01) {
            return bitmap
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
        return Bitmap.createBitmap(bitmap, left, top, cropWidth, cropHeight)
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
            "lensFacing" to if (lensMode == NativeLensMode.Front) "front" else "back",
            "lensMode" to lensMode.value,
            "supportsTelephoto" to (telephotoCameraId != null),
        )
    }

    private data class CameraInfo(
        val cameraId: String,
        val focalLength: Float,
        val physicalIds: Set<String>,
    )
}

internal fun photoLocationFromCall(call: MethodCall): Location? {
    val latitude = (call.argument<Number>("latitude") ?: return null).toDouble()
    val longitude = (call.argument<Number>("longitude") ?: return null).toDouble()
    if (!latitude.isFinite() || !longitude.isFinite() ||
        latitude !in -90.0..90.0 || longitude !in -180.0..180.0
    ) {
        return null
    }
    return Location("MiriaGo").apply {
        this.latitude = latitude
        this.longitude = longitude
        (call.argument<Number>("accuracy")?.toFloat())?.let {
            if (it.isFinite() && it >= 0f) accuracy = it
        }
        (call.argument<Number>("altitude")?.toDouble())?.let {
            if (it.isFinite()) altitude = it
        }
        time = call.argument<Number>("locationTimestampMillis")?.toLong()
            ?: System.currentTimeMillis()
    }
}

// Writes GPS EXIF for `writePhotoLocation` calls on a background executor.
// Shared by the preview view channel and the app-level fallback channel.
internal fun writePhotoLocationCall(
    call: MethodCall,
    result: MethodChannel.Result,
    activity: MainActivity,
    executor: Executor,
) {
    val path = call.argument<String>("path")
    val location = photoLocationFromCall(call)
    if (path.isNullOrBlank() || location == null) {
        result.error("invalid_photo_location", "Photo path or location is invalid.", null)
        return
    }
    try {
        executor.execute {
            try {
                val file = File(path)
                if (!file.isFile) {
                    throw IllegalArgumentException("Photo file does not exist.")
                }
                ExifInterface(file.absolutePath).apply {
                    setGpsInfo(location)
                    saveAttributes()
                }
                activity.runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    result.error("photo_location_write_failed", error.message, null)
                }
            }
        }
    } catch (error: RejectedExecutionException) {
        result.error("photo_location_write_failed", error.message, null)
    }
}
