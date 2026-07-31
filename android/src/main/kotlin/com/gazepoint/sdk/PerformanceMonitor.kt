package com.gazepoint.sdk

import android.util.Log
import java.util.concurrent.ConcurrentLinkedQueue
import kotlin.math.roundToInt

/**
 * Performance monitor for tracking FPS, processing time, and other metrics.
 */
class PerformanceMonitor {

    companion object {
        private const val TAG = "PerformanceMonitor"
        private const val WINDOW_SIZE = 30
    }

    private val frameTimestamps = ConcurrentLinkedQueue<Long>()
    private val processingTimes = ConcurrentLinkedQueue<Long>()
    private var lastFrameTime = 0L
    private var frameCount = 0L
    private var totalProcessingTime = 0L

    data class PerformanceMetrics(
        val fps: Float,
        val avgProcessingTimeMs: Float,
        val maxProcessingTimeMs: Long,
        val droppedFrames: Int,
        val totalFrames: Long
    )

    fun startFrame(): Long = System.nanoTime()

    fun endFrame(startTime: Long) {
        val currentTime = System.nanoTime()
        val processingTime = (currentTime - startTime) / 1_000_000

        frameCount++
        totalProcessingTime += processingTime

        frameTimestamps.offer(currentTime)
        processingTimes.offer(processingTime)

        while (frameTimestamps.size > WINDOW_SIZE) {
            frameTimestamps.poll()
            processingTimes.poll()
        }

        lastFrameTime = currentTime
    }

    fun getMetrics(): PerformanceMetrics {
        if (frameTimestamps.isEmpty()) {
            return PerformanceMetrics(0f, 0f, 0L, 0, frameCount)
        }

        val timestamps = frameTimestamps.toList()
        val fps = if (timestamps.size > 1) {
            val timeSpan = (timestamps.last() - timestamps.first()) / 1_000_000_000.0
            if (timeSpan > 0) (timestamps.size / timeSpan).toFloat() else 0f
        } else {
            0f
        }

        val times = processingTimes.toList()
        val avgProcessingTime = if (times.isNotEmpty()) times.average().toFloat() else 0f
        val maxProcessingTime = times.maxOrNull() ?: 0L
        val targetFrameTime = 1000f / 30f
        val droppedFrames = times.count { it > targetFrameTime }

        return PerformanceMetrics(
            fps = fps,
            avgProcessingTimeMs = avgProcessingTime,
            maxProcessingTimeMs = maxProcessingTime,
            droppedFrames = droppedFrames,
            totalFrames = frameCount
        )
    }

    fun logMetrics() {
        val metrics = getMetrics()
        Log.d(
            TAG,
            """
            Performance Metrics:
            FPS: ${metrics.fps.roundToInt()}
            Avg Processing Time: ${metrics.avgProcessingTimeMs.roundToInt()} ms
            Max Processing Time: ${metrics.maxProcessingTimeMs} ms
            Dropped Frames: ${metrics.droppedFrames}
            Total Frames: ${metrics.totalFrames}
            """.trimIndent()
        )
    }

    fun reset() {
        frameTimestamps.clear()
        processingTimes.clear()
        lastFrameTime = 0L
        frameCount = 0L
        totalProcessingTime = 0L
    }

    fun isPerformanceDegraded(): Boolean {
        val metrics = getMetrics()
        return metrics.fps < 15f || metrics.avgProcessingTimeMs > 100f
    }
}
