import Foundation

/// Performance monitor for tracking FPS, processing time, and other metrics
public class PerformanceMonitor {

    public struct PerformanceMetrics: Codable {
        public let fps: Float
        public let avgProcessingTimeMs: Float
        public let maxProcessingTimeMs: Float
        public let droppedFrames: Int
        public let totalFrames: Int64

        public init(
            fps: Float,
            avgProcessingTimeMs: Float,
            maxProcessingTimeMs: Float,
            droppedFrames: Int,
            totalFrames: Int64
        ) {
            self.fps = fps
            self.avgProcessingTimeMs = avgProcessingTimeMs
            self.maxProcessingTimeMs = maxProcessingTimeMs
            self.droppedFrames = droppedFrames
            self.totalFrames = totalFrames
        }
    }

    private let windowSize = 30
    private let targetFPS: Float = 30.0

    private var frameTimestamps: [TimeInterval] = []
    private var processingTimes: [TimeInterval] = []
    private var frameCount: Int64 = 0
    private var totalProcessingTime: TimeInterval = 0

    private let queue = DispatchQueue(
        label: "com.gazepoint.macos.performancemonitor",
        attributes: .concurrent
    )

    public init() {}

    public func startFrame() -> TimeInterval {
        return Date().timeIntervalSince1970
    }

    public func endFrame(startTime: TimeInterval) {
        let currentTime = Date().timeIntervalSince1970
        let processingTime = (currentTime - startTime) * 1000

        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }

            self.frameCount += 1
            self.totalProcessingTime += processingTime
            self.frameTimestamps.append(currentTime)
            self.processingTimes.append(processingTime)

            if self.frameTimestamps.count > self.windowSize {
                self.frameTimestamps.removeFirst()
                self.processingTimes.removeFirst()
            }
        }
    }

    public func getMetrics() -> PerformanceMetrics {
        return queue.sync {
            guard !frameTimestamps.isEmpty else {
                return PerformanceMetrics(
                    fps: 0,
                    avgProcessingTimeMs: 0,
                    maxProcessingTimeMs: 0,
                    droppedFrames: 0,
                    totalFrames: frameCount
                )
            }

            let fps: Float
            if frameTimestamps.count > 1 {
                let timeSpan = frameTimestamps.last! - frameTimestamps.first!
                fps = timeSpan > 0 ? Float(frameTimestamps.count) / Float(timeSpan) : 0
            } else {
                fps = 0
            }

            let avgProcessingTime = processingTimes.isEmpty
                ? 0
                : Float(processingTimes.reduce(0, +) / Double(processingTimes.count))
            let maxProcessingTime = processingTimes.max() ?? 0
            let targetFrameTime = 1000.0 / Double(targetFPS)
            let droppedFrames = processingTimes.filter { $0 > targetFrameTime }.count

            return PerformanceMetrics(
                fps: fps,
                avgProcessingTimeMs: avgProcessingTime,
                maxProcessingTimeMs: Float(maxProcessingTime),
                droppedFrames: droppedFrames,
                totalFrames: frameCount
            )
        }
    }

    public func reset() {
        queue.async(flags: .barrier) { [weak self] in
            self?.frameTimestamps.removeAll()
            self?.processingTimes.removeAll()
            self?.frameCount = 0
            self?.totalProcessingTime = 0
        }
    }
}
