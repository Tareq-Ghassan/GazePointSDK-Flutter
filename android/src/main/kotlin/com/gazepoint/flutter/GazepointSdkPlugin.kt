package com.gazepoint.flutter

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.PointF
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.gazepoint.sdk.camera.GazeCamera
import com.gazepoint.sdk.camera.GazeCameraOptions
import com.gazepoint.sdk.camera.GazeFrame
import com.gazepoint.sdk.camera.GazePreviewView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/**
 * Flutter wrapper around the Android GazePoint SDK ([GazeCamera]).
 */
class GazepointSdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var gazeCamera: GazeCamera? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: Result? = null
    private var pendingPreview: GazePreviewView? = null
    private var isInitialized = false
    private var latestResult: Map<String, Any?>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "gazepoint_sdk")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "gazepoint_sdk/gaze_stream")
        eventChannel.setStreamHandler(this)
        binding.platformViewRegistry.registerViewFactory(
            "gazepoint_sdk/preview",
            GazePreviewFactory(this)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        gazeCamera?.dispose()
        gazeCamera = null
        applicationContext = null
        isInitialized = false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        gazeCamera?.stop()
        activity = null
        activityBinding = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    internal fun attachPreview(view: GazePreviewView) {
        pendingPreview = view
        gazeCamera?.attachPreview(view)
    }

    internal fun detachPreview(view: GazePreviewView) {
        if (pendingPreview === view) {
            pendingPreview = null
        }
        gazeCamera?.detachPreview(view)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val context = applicationContext
                if (context == null) {
                    result.error("NO_CONTEXT", "Plugin not attached", null)
                    return
                }
                val previewEnabled = call.argument<Boolean>("previewEnabled") ?: false
                val showFaceBoxes = call.argument<Boolean>("showFaceBoxes") ?: true
                if (gazeCamera == null) {
                    gazeCamera = GazeCamera(context) { frame ->
                        val mapped = toMap(frame)
                        latestResult = mapped
                        activity?.runOnUiThread {
                            eventSink?.success(mapped)
                        }
                    }
                }
                gazeCamera?.configure(
                    GazeCameraOptions(
                        previewEnabled = previewEnabled,
                        showFaceBoxes = showFaceBoxes
                    )
                )
                pendingPreview?.let { gazeCamera?.attachPreview(it) }
                isInitialized = true
                result.success(null)
            }

            "startTracking" -> {
                val owner = activity as? LifecycleOwner
                if (owner == null) {
                    result.error("NO_ACTIVITY", "Activity not available", null)
                    return
                }
                if (!isInitialized || gazeCamera == null) {
                    result.error("NOT_INITIALIZED", "Call initialize() first", null)
                    return
                }
                gazeCamera?.start(owner)
                result.success(null)
            }

            "stopTracking" -> {
                gazeCamera?.stop()
                result.success(null)
            }

            "setPreviewEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                gazeCamera?.previewEnabled = enabled
                result.success(null)
            }

            "switchCamera" -> {
                gazeCamera?.switchCamera()
                result.success(null)
            }

            "getLatestGaze" -> {
                result.success(latestResult)
            }

            "calibrate" -> {
                val rawPoints = call.argument<List<Map<String, Any>>>("calibrationPoints")
                if (rawPoints == null || rawPoints.size < 3) {
                    result.error("INVALID_ARGS", "At least 3 calibration points required", null)
                    return
                }
                val points = rawPoints.mapNotNull { map ->
                    val expected = map["expected"] as? Map<*, *>
                    val actual = map["actual"] as? Map<*, *>
                    if (expected == null || actual == null) return@mapNotNull null
                    val expectedX = (expected["x"] as? Number)?.toFloat() ?: return@mapNotNull null
                    val expectedY = (expected["y"] as? Number)?.toFloat() ?: return@mapNotNull null
                    val actualX = (actual["x"] as? Number)?.toFloat() ?: return@mapNotNull null
                    val actualY = (actual["y"] as? Number)?.toFloat() ?: return@mapNotNull null
                    PointF(expectedX, expectedY) to PointF(actualX, actualY)
                }
                if (points.size < 3) {
                    result.error("INVALID_ARGS", "Invalid calibration point format", null)
                    return
                }
                gazeCamera?.calibrate(points)
                result.success(null)
            }

            "resetCalibration" -> {
                gazeCamera?.resetCalibration()
                result.success(null)
            }

            "getPerformanceMetrics" -> {
                val metrics = gazeCamera?.getPerformanceMetrics()
                if (metrics == null) {
                    result.error("NOT_INITIALIZED", "Tracker not initialized", null)
                } else {
                    result.success(
                        mapOf(
                            "fps" to metrics.fps.toDouble(),
                            "avgProcessingTimeMs" to metrics.avgProcessingTimeMs.toDouble(),
                            "maxProcessingTimeMs" to metrics.maxProcessingTimeMs.toDouble(),
                            "droppedFrames" to metrics.droppedFrames,
                            "totalFrames" to metrics.totalFrames
                        )
                    )
                }
            }

            "isSupported" -> {
                val context = applicationContext
                if (context == null) {
                    result.success(false)
                    return
                }
                val hasCamera = context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
                val hasFront = context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FRONT)
                result.success(hasCamera && hasFront)
            }

            "hasCameraPermission" -> {
                val context = applicationContext
                if (context == null) {
                    result.success(false)
                    return
                }
                val granted = ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.CAMERA
                ) == PackageManager.PERMISSION_GRANTED
                result.success(granted)
            }

            "requestCameraPermission" -> {
                val currentActivity = activity
                if (currentActivity == null) {
                    result.error("NO_ACTIVITY", "Activity not available", null)
                    return
                }
                if (ContextCompat.checkSelfPermission(
                        currentActivity,
                        Manifest.permission.CAMERA
                    ) == PackageManager.PERMISSION_GRANTED
                ) {
                    result.success(true)
                    return
                }
                pendingPermissionResult = result
                ActivityCompat.requestPermissions(
                    currentActivity,
                    arrayOf(Manifest.permission.CAMERA),
                    REQUEST_CAMERA
                )
            }

            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != REQUEST_CAMERA) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        return true
    }

    private fun toMap(frame: GazeFrame): Map<String, Any?> {
        val gaze = frame.gaze
        val map = mutableMapOf<String, Any?>(
            "faceDetected" to frame.faceDetected,
            "faceCount" to frame.faceCount,
            "statusText" to frame.statusText,
            "timestamp" to System.currentTimeMillis()
        )
        if (gaze != null) {
            map["gazePointX"] = gaze.gazePoint.x.toDouble()
            map["gazePointY"] = gaze.gazePoint.y.toDouble()
            map["confidence"] = gaze.confidence.toDouble()
            map["isBlinking"] = gaze.isBlinking
            map["headPose"] = mapOf(
                "pitch" to gaze.headPose.pitch.toDouble(),
                "yaw" to gaze.headPose.yaw.toDouble(),
                "roll" to gaze.headPose.roll.toDouble()
            )
        }
        return map
    }

    companion object {
        private const val REQUEST_CAMERA = 19283
    }
}
