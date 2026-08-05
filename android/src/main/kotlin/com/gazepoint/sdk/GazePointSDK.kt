package com.gazepoint.sdk

/**
 * GazePointSDK - Android Eye Tracking and Gaze Point Detection
 *
 * This SDK provides real-time eye tracking and gaze point detection for Android applications.
 * It uses Google ML Kit for face and landmark detection, with advanced algorithms
 * for accurate gaze estimation.
 *
 * Features:
 * - Real-time gaze point tracking
 * - Head pose compensation
 * - Blink detection
 * - Kalman filtering for smooth tracking
 * - Performance monitoring
 * - Calibration support
 *
 * Example usage:
 * ```kotlin
 * val gazeTracker = GazeTracker(context)
 *
 * // From an ML Kit Face
 * gazeTracker.calculateGazePoint(face)?.let { result ->
 *     println("Gaze point: ${result.gazePoint}")
 *     println("Confidence: ${result.confidence}")
 *     println("Blinking: ${result.isBlinking}")
 * }
 *
 * // Calibration
 * gazeTracker.calibrate(
 *     listOf(
 *         PointF(100f, 100f) to PointF(95f, 102f),
 *         PointF(200f, 200f) to PointF(198f, 205f),
 *         PointF(300f, 300f) to PointF(305f, 295f),
 *     )
 * )
 * ```
 */
object GazePointSDK {
    /** Current version of the SDK */
    const val VERSION = "2.1.0"

    /** Build number */
    const val BUILD = "1"

    /** Full version string */
    val fullVersion: String
        get() = "$VERSION ($BUILD)"

    /** Print SDK information to logcat-friendly stdout. */
    fun printInfo() {
        println(
            """
            ╔═══════════════════════════════════════╗
            ║      GazePoint SDK for Android        ║
            ║      Version: $VERSION                  ║
            ║      Build: $BUILD                      ║
            ╚═══════════════════════════════════════╝

            Features:
            ✓ Real-time gaze tracking
            ✓ Head pose compensation
            ✓ Blink detection
            ✓ Kalman filtering
            ✓ Performance monitoring
            ✓ Calibration support

            Requirements:
            • Android 24+
            • Camera access permission
            • ML Kit face detection
            """.trimIndent()
        )
    }
}
