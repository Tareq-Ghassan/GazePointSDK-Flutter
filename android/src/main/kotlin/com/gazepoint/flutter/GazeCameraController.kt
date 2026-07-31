package com.gazepoint.flutter

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PointF
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.gazepoint.sdk.GazeTracker
import com.gazepoint.sdk.PerformanceMonitor
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import java.util.concurrent.Executors

/**
 * Headless CameraX + ML Kit pipeline that feeds [GazeTracker] from the Android SDK.
 */
class GazeCameraController(
    private val context: Context,
    private val onGazeResult: (Map<String, Any?>?) -> Unit
) {
    companion object {
        private const val TAG = "GazeCameraController"
    }

    private val cameraExecutor = Executors.newSingleThreadExecutor()
    private var cameraProvider: ProcessCameraProvider? = null
    private var gazeTracker: GazeTracker? = null
    private val performanceMonitor = PerformanceMonitor()
    private var latestResult: Map<String, Any?>? = null
    private var isRunning = false

    private val faceDetector: FaceDetector = FaceDetection.getClient(
        FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
            .setMinFaceSize(0.15f)
            .enableTracking()
            .build()
    )

    fun initialize() {
        if (gazeTracker == null) {
            gazeTracker = GazeTracker(context.applicationContext)
        }
    }

    fun start(lifecycleOwner: LifecycleOwner) {
        if (isRunning) return
        initialize()

        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            try {
                cameraProvider = future.get()
                bindAnalysis(lifecycleOwner)
                isRunning = true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start camera", e)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun bindAnalysis(lifecycleOwner: LifecycleOwner) {
        val provider = cameraProvider ?: return

        val imageAnalysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also { it.setAnalyzer(cameraExecutor, ::analyzeFrame) }

        val cameraSelector = CameraSelector.Builder()
            .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
            .build()

        try {
            provider.unbindAll()
            provider.bindToLifecycle(lifecycleOwner, cameraSelector, imageAnalysis)
        } catch (e: Exception) {
            Log.e(TAG, "Use case binding failed", e)
        }
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun analyzeFrame(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return
        }

        val inputImage = InputImage.fromMediaImage(
            mediaImage,
            imageProxy.imageInfo.rotationDegrees
        )
        val startTime = performanceMonitor.startFrame()

        faceDetector.process(inputImage)
            .addOnSuccessListener { faces ->
                val tracker = gazeTracker
                val primary = selectPrimaryFace(faces)
                val result = primary?.let { tracker?.calculateGazePoint(it) }
                val mapped = result?.let { toMap(it) }
                latestResult = mapped
                onGazeResult(mapped)
                performanceMonitor.endFrame(startTime)
                imageProxy.close()
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Face detection failed", e)
                onGazeResult(null)
                performanceMonitor.endFrame(startTime)
                imageProxy.close()
            }
    }

    private fun selectPrimaryFace(faces: List<Face>): Face? {
        return faces.maxByOrNull { face ->
            val box = face.boundingBox
            val area = box.width() * box.height()
            val trackingScore = if (face.trackingId != null) 1000 else 0
            area + trackingScore
        }
    }

    private fun toMap(result: GazeTracker.GazeResult): Map<String, Any?> {
        return mapOf(
            "gazePointX" to result.gazePoint.x.toDouble(),
            "gazePointY" to result.gazePoint.y.toDouble(),
            "confidence" to result.confidence.toDouble(),
            "isBlinking" to result.isBlinking,
            "headPose" to mapOf(
                "pitch" to result.headPose.pitch.toDouble(),
                "yaw" to result.headPose.yaw.toDouble(),
                "roll" to result.headPose.roll.toDouble()
            ),
            "timestamp" to System.currentTimeMillis()
        )
    }

    fun getLatestGaze(): Map<String, Any?>? = latestResult

    fun getPerformanceMetrics(): Map<String, Any?> {
        val metrics = performanceMonitor.getMetrics()
        return mapOf(
            "fps" to metrics.fps.toDouble(),
            "avgProcessingTimeMs" to metrics.avgProcessingTimeMs.toDouble(),
            "maxProcessingTimeMs" to metrics.maxProcessingTimeMs.toDouble(),
            "droppedFrames" to metrics.droppedFrames,
            "totalFrames" to metrics.totalFrames
        )
    }

    fun calibrate(points: List<Pair<PointF, PointF>>) {
        gazeTracker?.calibrate(points)
    }

    fun resetCalibration() {
        gazeTracker?.resetCalibration()
    }

    fun stop() {
        isRunning = false
        try {
            cameraProvider?.unbindAll()
        } catch (e: Exception) {
            Log.e(TAG, "Error unbinding camera", e)
        }
    }

    fun dispose() {
        stop()
        try {
            faceDetector.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing face detector", e)
        }
        cameraExecutor.shutdown()
        gazeTracker = null
        latestResult = null
    }
}
