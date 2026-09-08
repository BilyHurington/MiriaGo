package app.miriago.miriago

import android.app.Activity
import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import android.view.Surface
import io.flutter.plugin.common.EventChannel

internal class MapHeadingStream(private val activity: Activity) :
    EventChannel.StreamHandler, SensorEventListener {
    private val manager = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val sensor = manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        ?: manager.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
    private var sink: EventChannel.EventSink? = null
    private var resumed = false
    private var declination = 0.0
    private var lastEventMillis = 0L
    private val matrix = FloatArray(9)
    private val adjusted = FloatArray(9)
    private val orientation = FloatArray(3)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        manager.unregisterListener(this)
        sink = events
        val args = arguments as? Map<*, *>
        val latitude = (args?.get("latitude") as? Number)?.toFloat() ?: 0f
        val longitude = (args?.get("longitude") as? Number)?.toFloat() ?: 0f
        declination = GeomagneticField(latitude, longitude, 0f, System.currentTimeMillis())
            .declination.toDouble()
        lastEventMillis = 0L
        start()
    }

    fun resume() { resumed = true; start() }
    fun pause() { resumed = false; manager.unregisterListener(this) }

    private fun start() {
        if (!resumed || sink == null) return
        if (sensor == null || !manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)) {
            sink?.success(null)
        }
    }

    override fun onCancel(arguments: Any?) {
        manager.unregisterListener(this)
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        if (accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE) sink?.success(null)
    }

    override fun onSensorChanged(event: SensorEvent) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastEventMillis < 100) return
        lastEventMillis = now
        if (event.accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE) {
            sink?.success(null)
            return
        }
        SensorManager.getRotationMatrixFromVector(matrix, event.values)
        @Suppress("DEPRECATION")
        val rotation = activity.windowManager.defaultDisplay.rotation
        val axes = when (rotation) {
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
        SensorManager.remapCoordinateSystem(matrix, axes.first, axes.second, adjusted)
        SensorManager.getOrientation(adjusted, orientation)
        val degrees = Math.toDegrees(orientation[0].toDouble()) + declination
        sink?.success((degrees % 360 + 360) % 360)
    }
}
