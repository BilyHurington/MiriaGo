package app.miriago.miriago

import android.Manifest
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

private const val MAX_INCOMING_PLAN_BYTES = 128L * 1024 * 1024
private const val INCOMING_PLAN_DIRECTORY = "incoming_plans"
private const val GALLERY_PERMISSION_REQUEST_CODE = 0x5E1C
private const val GALLERY_RELATIVE_DIRECTORY = "SeichiJunrei"

private class PlanFileTooLargeException : IOException("Plan file exceeds the import size limit.")

class MainActivity : FlutterActivity() {
    private var planFileChannel: MethodChannel? = null
    private var pendingPlanPath: String? = null
    private var pendingPlanError: Pair<String, String>? = null
    private var initialPlanPathDelivered = false
    private var planCopiesInFlight = 0
    private val initialPlanPathRequests = mutableListOf<MethodChannel.Result>()
    private var restoredFromSavedState = false
    private var mapHeading: MapHeadingStream? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val photoLocationExecutor: ExecutorService by lazy {
        Executors.newSingleThreadExecutor()
    }
    // Incoming plan copies and gallery writes do file I/O that must never run
    // on the main thread.
    private val planFileExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val galleryExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var pendingGallerySave: Pair<String, MethodChannel.Result>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // A process restored from saved state still carries the original VIEW
        // intent; it must not replay an import the user already handled.
        restoredFromSavedState = savedInstanceState != null
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        planFileExecutor.shutdown()
        galleryExecutor.shutdown()
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        mapHeading?.resume()
    }

    override fun onPause() {
        mapHeading?.pause()
        super.onPause()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        mapHeading?.onCancel(null)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "miriago/map_heading")
            .setStreamHandler(null)
        mapHeading = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mapHeading = MapHeadingStream(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "miriago/map_heading")
            .setStreamHandler(mapHeading)
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
        // Location writes that do not depend on a live native preview view
        // (used by the CameraAwesome fallback camera).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seichi/photo_location"
        ).setMethodCallHandler { call, result ->
            if (call.method == "writePhotoLocation") {
                writePhotoLocationCall(call, result, this, photoLocationExecutor)
            } else {
                result.notImplemented()
            }
        }
        val mapNavigationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "miriago/map_navigation"
        )
        planFileChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seichi/plan_file"
        )

        pendingPlanPath = null
        pendingPlanError = null
        initialPlanPathDelivered = false
        // Copies left behind by a crash or an import that never finished.
        runOnPlanFileExecutor { deleteStaleIncomingPlanCopies() }
        if (!restoredFromSavedState) {
            incomingPlanUri(intent)?.let { startIncomingPlanCopy(it) }
        }
        planFileChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialPath" -> {
                    if (planCopiesInFlight > 0) {
                        initialPlanPathRequests.add(result)
                    } else {
                        deliverInitialPlanPath(result)
                    }
                }
                "releasePath" -> {
                    val path = call.arguments as? String
                    if (path != null) {
                        runOnPlanFileExecutor { deleteIncomingPlanCopy(path) }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        galleryChannel.setMethodCallHandler { call, result ->
            if (call.method == "saveToGallery") {
                val filePath = call.argument<String>("filePath")
                if (filePath == null) {
                    result.error("INVALID_ARGUMENT", "filePath is required", null)
                    return@setMethodCallHandler
                }
                saveToGalleryWithPermission(filePath, result)
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

        mapNavigationChannel.setMethodCallHandler { call, result ->
            if (call.method != "openGoogleMapsWalking") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val latitude = call.argument<Number>("latitude")?.toDouble()
            val longitude = call.argument<Number>("longitude")?.toDouble()
            if (latitude == null || longitude == null) {
                result.error("INVALID_ARGUMENT", "latitude and longitude are required", null)
                return@setMethodCallHandler
            }
            result.success(openGoogleMapsWalking(latitude, longitude))
        }
    }

    private fun openGoogleMapsWalking(latitude: Double, longitude: Double): Boolean {
        val navigationUri = Uri.parse(
            "google.navigation:q=$latitude,$longitude&mode=w"
        )
        val mapIntent = Intent(Intent.ACTION_VIEW, navigationUri).apply {
            setPackage("com.google.android.apps.maps")
        }
        if (mapIntent.resolveActivity(packageManager) == null) {
            return false
        }
        return try {
            startActivity(mapIntent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = incomingPlanUri(intent) ?: return
        startIncomingPlanCopy(uri)
    }

    private fun saveToGalleryWithPermission(filePath: String, result: MethodChannel.Result) {
        // API 24-28 have no scoped storage: writing to shared Pictures needs
        // WRITE_EXTERNAL_STORAGE (declared with maxSdkVersion=28).
        if (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            pendingGallerySave?.second?.error(
                "SAVE_SUPERSEDED",
                "A newer gallery save request replaced this one.",
                null
            )
            pendingGallerySave = filePath to result
            requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                GALLERY_PERMISSION_REQUEST_CODE
            )
            return
        }
        runGallerySave(filePath, result)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != GALLERY_PERMISSION_REQUEST_CODE) return
        val (filePath, result) = pendingGallerySave ?: return
        pendingGallerySave = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            runGallerySave(filePath, result)
        } else {
            result.error("PERMISSION_DENIED", "Storage permission was denied.", null)
        }
    }

    private fun runGallerySave(filePath: String, result: MethodChannel.Result) {
        try {
            galleryExecutor.execute {
                try {
                    val savedPath = saveImageToGallery(filePath)
                    mainHandler.post { result.success(savedPath) }
                } catch (e: Exception) {
                    mainHandler.post { result.error("SAVE_FAILED", e.message, null) }
                }
            }
        } catch (e: RejectedExecutionException) {
            result.error("SAVE_FAILED", e.message, null)
        }
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
        val displayName = "seichi_${sourceFile.name}"

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveImageToMediaStore(sourceFile, displayName, mimeType)
        } else {
            saveImageToLegacyPictures(sourceFile, displayName, mimeType)
        }
    }

    private fun saveImageToMediaStore(
        sourceFile: File,
        displayName: String,
        mimeType: String
    ): String? {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            put(MediaStore.Images.Media.IS_PENDING, 1)
            put(
                MediaStore.Images.Media.RELATIVE_PATH,
                Environment.DIRECTORY_PICTURES + "/" + GALLERY_RELATIVE_DIRECTORY
            )
        }

        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: return null

        try {
            val output = resolver.openOutputStream(uri)
                ?: throw IOException("Cannot open MediaStore output stream.")
            output.use { stream ->
                sourceFile.inputStream().use { input -> input.copyTo(stream) }
            }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (error: Exception) {
            // Do not leave an invisible, half-written pending row behind.
            try {
                resolver.delete(uri, null, null)
            } catch (_: Exception) {
            }
            throw error
        }

        return uri.toString()
    }

    // Before API 29 MediaStore has no RELATIVE_PATH/IS_PENDING: write the file
    // into shared Pictures ourselves and index it through the DATA column.
    @Suppress("DEPRECATION")
    private fun saveImageToLegacyPictures(
        sourceFile: File,
        displayName: String,
        mimeType: String
    ): String? {
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            GALLERY_RELATIVE_DIRECTORY
        )
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw IOException("Cannot create ${directory.absolutePath}.")
        }
        val target = uniqueFile(directory, displayName)
        try {
            sourceFile.inputStream().use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
        } catch (error: Exception) {
            target.delete()
            throw error
        }

        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, target.name)
            put(MediaStore.Images.Media.TITLE, target.nameWithoutExtension)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            put(MediaStore.Images.Media.DATA, target.absolutePath)
            put(MediaStore.Images.Media.DATE_ADDED, System.currentTimeMillis() / 1000)
            put(MediaStore.Images.Media.DATE_TAKEN, System.currentTimeMillis())
        }
        val uri = try {
            contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        } catch (_: Exception) {
            null
        }
        if (uri == null) {
            // The file is saved; let the media scanner index it instead.
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(target.absolutePath),
                arrayOf(mimeType),
                null
            )
            return Uri.fromFile(target).toString()
        }
        return uri.toString()
    }

    private fun uniqueFile(directory: File, name: String): File {
        var candidate = File(directory, name)
        if (!candidate.exists()) return candidate
        val base = candidate.nameWithoutExtension
        val extension = candidate.extension.let { if (it.isEmpty()) "" else ".$it" }
        var index = 1
        while (candidate.exists()) {
            candidate = File(directory, "${base}_$index$extension")
            index++
        }
        return candidate
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

    private fun incomingPlanUri(intent: Intent?): Uri? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        // Reopening from Recents re-delivers the original VIEW intent.
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return null
        val uri = intent.data ?: return null
        // Only content:// URIs; file:// would let other apps point the copy at
        // arbitrary paths readable by MiriaGo.
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) return null
        return uri
    }

    private fun runOnPlanFileExecutor(block: () -> Unit): Boolean {
        return try {
            planFileExecutor.execute(block)
            true
        } catch (_: RejectedExecutionException) {
            false
        }
    }

    private fun startIncomingPlanCopy(uri: Uri) {
        planCopiesInFlight++
        val scheduled = runOnPlanFileExecutor {
            var copied: File? = null
            var error: Pair<String, String>? = null
            try {
                copied = copyPlanUriToCache(uri)
            } catch (_: PlanFileTooLargeException) {
                error = "PLAN_FILE_TOO_LARGE" to "Plan file exceeds $MAX_INCOMING_PLAN_BYTES bytes."
            } catch (e: Exception) {
                error = "PLAN_FILE_COPY_FAILED" to (e.message ?: "Cannot read the plan file.")
            }
            mainHandler.post { onIncomingPlanCopyFinished(copied, error) }
        }
        if (!scheduled) {
            planCopiesInFlight--
        }
    }

    private fun onIncomingPlanCopyFinished(copied: File?, error: Pair<String, String>?) {
        planCopiesInFlight--
        if (isDestroyed) {
            copied?.delete()
            return
        }
        if (!initialPlanPathDelivered) {
            if (copied != null) {
                pendingPlanPath?.let { stale ->
                    runOnPlanFileExecutor { deleteIncomingPlanCopy(stale) }
                }
                pendingPlanPath = copied.absolutePath
                pendingPlanError = null
            } else if (pendingPlanPath == null) {
                pendingPlanError = error
            }
            if (planCopiesInFlight == 0 && initialPlanPathRequests.isNotEmpty()) {
                val requests = initialPlanPathRequests.toList()
                initialPlanPathRequests.clear()
                deliverInitialPlanPath(requests.first())
                requests.drop(1).forEach { it.success(null) }
            }
            return
        }
        if (copied != null) {
            planFileChannel?.invokeMethod("openPath", copied.absolutePath)
        } else if (error != null) {
            planFileChannel?.invokeMethod(
                "openPathFailed",
                mapOf("code" to error.first, "message" to error.second)
            )
        }
    }

    private fun deliverInitialPlanPath(result: MethodChannel.Result) {
        initialPlanPathDelivered = true
        val path = pendingPlanPath
        val error = pendingPlanError
        pendingPlanPath = null
        pendingPlanError = null
        if (path == null && error != null) {
            result.error(error.first, error.second, null)
        } else {
            result.success(path)
        }
    }

    private fun incomingPlanDirectory(): File = File(cacheDir, INCOMING_PLAN_DIRECTORY)

    private fun copyPlanUriToCache(uri: Uri): File {
        val declaredSize = try {
            contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else null
                }
        } catch (_: Exception) {
            null
        }
        if (declaredSize != null && declaredSize > MAX_INCOMING_PLAN_BYTES) {
            throw PlanFileTooLargeException()
        }

        val directory = incomingPlanDirectory()
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw IOException("Cannot create ${directory.absolutePath}.")
        }
        val file = File.createTempFile("incoming_", ".sjhplan", directory)
        try {
            val input = contentResolver.openInputStream(uri)
                ?: throw IOException("Cannot open $uri.")
            input.use { source ->
                file.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val read = source.read(buffer)
                        if (read < 0) break
                        total += read
                        // The provider's declared size can be missing or wrong.
                        if (total > MAX_INCOMING_PLAN_BYTES) {
                            throw PlanFileTooLargeException()
                        }
                        output.write(buffer, 0, read)
                    }
                }
            }
            return file
        } catch (error: Exception) {
            file.delete()
            throw error
        }
    }

    private fun deleteIncomingPlanCopy(path: String) {
        val directory = incomingPlanDirectory().canonicalFile
        val file = File(path).canonicalFile
        if (file.parentFile == directory && file.isFile) {
            file.delete()
        }
    }

    // Copies created before this process started belong to an import whose
    // Dart side is gone (crash, kill); copies from this process may still be
    // read by another MainActivity instance and are released explicitly.
    private fun deleteStaleIncomingPlanCopies() {
        val processStartedAt = System.currentTimeMillis() -
            (SystemClock.elapsedRealtime() - Process.getStartElapsedRealtime())
        incomingPlanDirectory().listFiles()?.forEach { file ->
            if (file.isFile && file.lastModified() < processStartedAt) file.delete()
        }
    }
}
