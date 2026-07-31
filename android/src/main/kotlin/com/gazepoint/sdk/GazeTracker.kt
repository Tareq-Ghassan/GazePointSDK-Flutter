package com.gazepoint.sdk

import android.content.Context
import android.graphics.PointF
import android.util.Log
import com.gazepoint.sdk.math.Vector3
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceLandmark
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Enhanced Gaze Tracker with improved accuracy and calibration support.
 *
 * Features:
 * - Kalman filtering for smooth tracking
 * - Multi-point calibration support
 * - Head pose compensation
 * - Adaptive smoothing based on movement speed
 * - Eye aspect ratio for blink detection
 */
class GazeTracker(private val context: Context) {

    companion object {
        private const val TAG = "GazeTracker"
        private const val SMOOTHING_FACTOR = 0.3f
        private const val BLINK_EAR_THRESHOLD = 0.2f
        private const val VELOCITY_THRESHOLD = 100f
    }

    private var lastGazePoint: PointF? = null
    private var calibrationData: CalibrationData? = null
    private var isCalibrated = false
    private var blinkDetected = false
    private val kalmanFilter = KalmanFilter()

    data class CalibrationData(
        val offsetX: Float = 0f,
        val offsetY: Float = 0f,
        val scaleX: Float = 1f,
        val scaleY: Float = 1f,
        val rotationCompensation: Float = 0f
    )

    data class GazeResult(
        val gazePoint: PointF,
        val confidence: Float,
        val isBlinking: Boolean,
        val headPose: HeadPose
    )

    data class HeadPose(
        val pitch: Float,
        val yaw: Float,
        val roll: Float
    )

    /**
     * Calculate gaze point from a detected ML Kit [Face].
     */
    fun calculateGazePoint(face: Face): GazeResult? {
        val leftEyeLandmark = face.getLandmark(FaceLandmark.LEFT_EYE)
        val rightEyeLandmark = face.getLandmark(FaceLandmark.RIGHT_EYE)

        if (leftEyeLandmark == null || rightEyeLandmark == null) {
            Log.w(TAG, "Eye landmarks not detected")
            return null
        }

        val leftEyePosition = leftEyeLandmark.position
        val rightEyePosition = rightEyeLandmark.position

        blinkDetected = detectBlink(face)
        val headPose = calculateHeadPose(face)
        val gazeVector = calculateGazeVector(leftEyePosition, rightEyePosition, headPose)

        val calibratedVector = if (isCalibrated && calibrationData != null) {
            applyCalibration(gazeVector, calibrationData!!)
        } else {
            gazeVector
        }

        val screenPoint = mapGazeVectorToScreenCoordinates(calibratedVector, headPose)
        val filteredPoint = kalmanFilter.update(screenPoint)
        val smoothedPoint = applyAdaptiveSmoothing(filteredPoint)
        val confidence = calculateConfidence(face, leftEyePosition, rightEyePosition)

        lastGazePoint = smoothedPoint

        return GazeResult(
            gazePoint = smoothedPoint,
            confidence = confidence,
            isBlinking = blinkDetected,
            headPose = headPose
        )
    }

    private fun calculateGazeVector(
        leftEyePosition: PointF,
        rightEyePosition: PointF,
        headPose: HeadPose
    ): Vector3 {
        val baseVector = Vector3(
            rightEyePosition.x - leftEyePosition.x,
            rightEyePosition.y - leftEyePosition.y,
            0f
        )

        val compensatedX = baseVector.x + headPose.yaw * 0.5f
        val compensatedY = baseVector.y + headPose.pitch * 0.5f
        val gazeVector = Vector3(compensatedX, compensatedY, 0f)

        val magnitude = sqrt(gazeVector.x * gazeVector.x + gazeVector.y * gazeVector.y)
        if (magnitude > 0) {
            return Vector3(gazeVector.x / magnitude, gazeVector.y / magnitude, 0f)
        }

        return gazeVector
    }

    private fun calculateHeadPose(face: Face): HeadPose {
        return HeadPose(
            pitch = face.headEulerAngleX,
            yaw = face.headEulerAngleY,
            roll = face.headEulerAngleZ
        )
    }

    private fun detectBlink(face: Face): Boolean {
        val leftEyeOpen = face.leftEyeOpenProbability ?: 1f
        val rightEyeOpen = face.rightEyeOpenProbability ?: 1f
        val avgEyeOpen = (leftEyeOpen + rightEyeOpen) / 2f
        return avgEyeOpen < BLINK_EAR_THRESHOLD
    }

    private fun mapGazeVectorToScreenCoordinates(
        gazeVector: Vector3,
        headPose: HeadPose
    ): PointF {
        val displayMetrics = context.resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels.toFloat()
        val screenHeight = displayMetrics.heightPixels.toFloat()

        val yawFactor = 1f + (abs(headPose.yaw) / 30f) * 0.2f
        val pitchFactor = 1f + (abs(headPose.pitch) / 30f) * 0.2f

        val screenX = (screenWidth / 2f) + (gazeVector.x * (screenWidth / 2f) * yawFactor)
        val screenY = (screenHeight / 2f) - (gazeVector.y * (screenHeight / 2f) * pitchFactor)

        return PointF(
            screenX.coerceIn(0f, screenWidth),
            screenY.coerceIn(0f, screenHeight)
        )
    }

    private fun applyCalibration(gazeVector: Vector3, calibration: CalibrationData): Vector3 {
        return Vector3(
            gazeVector.x * calibration.scaleX + calibration.offsetX,
            gazeVector.y * calibration.scaleY + calibration.offsetY,
            gazeVector.z
        )
    }

    private fun applyAdaptiveSmoothing(currentPoint: PointF): PointF {
        val lastPoint = lastGazePoint ?: return currentPoint

        val dx = currentPoint.x - lastPoint.x
        val dy = currentPoint.y - lastPoint.y
        val velocity = sqrt(dx * dx + dy * dy)

        val adaptiveFactor = if (velocity > VELOCITY_THRESHOLD) {
            SMOOTHING_FACTOR * 0.5f
        } else {
            SMOOTHING_FACTOR
        }

        return PointF(
            lastPoint.x + (currentPoint.x - lastPoint.x) * adaptiveFactor,
            lastPoint.y + (currentPoint.y - lastPoint.y) * adaptiveFactor
        )
    }

    private fun calculateConfidence(
        face: Face,
        leftEyePosition: PointF,
        rightEyePosition: PointF
    ): Float {
        var confidence = 1.0f

        confidence *= (face.trackingId ?: 0).let { if (it > 0) 1.0f else 0.8f }

        lastGazePoint?.let { last ->
            val eyeMidX = (leftEyePosition.x + rightEyePosition.x) / 2f
            val eyeMidY = (leftEyePosition.y + rightEyePosition.y) / 2f
            val stability = 1f - (abs(last.x - eyeMidX) + abs(last.y - eyeMidY)) / 1000f
            confidence *= stability.coerceIn(0.5f, 1.0f)
        }

        if (blinkDetected) {
            confidence *= 0.3f
        }

        return confidence.coerceIn(0f, 1f)
    }

    /**
     * Calibrate with known screen points: pairs of (expected, actual).
     * Requires at least 3 points.
     */
    fun calibrate(calibrationPoints: List<Pair<PointF, PointF>>) {
        if (calibrationPoints.size < 3) {
            Log.w(TAG, "Need at least 3 calibration points")
            return
        }

        var sumOffsetX = 0f
        var sumOffsetY = 0f
        var sumScaleX = 0f
        var sumScaleY = 0f

        calibrationPoints.forEach { (expected, actual) ->
            sumOffsetX += expected.x - actual.x
            sumOffsetY += expected.y - actual.y
            if (actual.x != 0f) sumScaleX += expected.x / actual.x
            if (actual.y != 0f) sumScaleY += expected.y / actual.y
        }

        val count = calibrationPoints.size
        calibrationData = CalibrationData(
            offsetX = sumOffsetX / count,
            offsetY = sumOffsetY / count,
            scaleX = sumScaleX / count,
            scaleY = sumScaleY / count
        )

        isCalibrated = true
        Log.i(TAG, "Calibration completed: $calibrationData")
    }

    fun resetCalibration() {
        calibrationData = null
        isCalibrated = false
        lastGazePoint = null
        kalmanFilter.reset()
    }

    private class KalmanFilter {
        private var estimateX = 0f
        private var estimateY = 0f
        private var errorCovarianceX = 1f
        private var errorCovarianceY = 1f

        private val processNoise = 0.01f
        private val measurementNoise = 0.1f

        fun update(measurement: PointF): PointF {
            val predictedErrorCovX = errorCovarianceX + processNoise
            val predictedErrorCovY = errorCovarianceY + processNoise

            val kalmanGainX = predictedErrorCovX / (predictedErrorCovX + measurementNoise)
            val kalmanGainY = predictedErrorCovY / (predictedErrorCovY + measurementNoise)

            estimateX += kalmanGainX * (measurement.x - estimateX)
            estimateY += kalmanGainY * (measurement.y - estimateY)

            errorCovarianceX = (1 - kalmanGainX) * predictedErrorCovX
            errorCovarianceY = (1 - kalmanGainY) * predictedErrorCovY

            return PointF(estimateX, estimateY)
        }

        fun reset() {
            estimateX = 0f
            estimateY = 0f
            errorCovarianceX = 1f
            errorCovarianceY = 1f
        }
    }
}
