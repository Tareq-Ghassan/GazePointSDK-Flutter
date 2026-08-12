import AppKit
import Foundation
import Vision

/// Gaze tracker for macOS using Vision face landmarks.
@available(macOS 12.0, *)
public class GazeTracker {

    public struct GazeResult {
        public let gazePoint: CGPoint
        public let confidence: Float
        public let isBlinking: Bool
        public let headPose: HeadPose
        public let timestamp: TimeInterval

        public init(
            gazePoint: CGPoint,
            confidence: Float,
            isBlinking: Bool,
            headPose: HeadPose,
            timestamp: TimeInterval
        ) {
            self.gazePoint = gazePoint
            self.confidence = confidence
            self.isBlinking = isBlinking
            self.headPose = headPose
            self.timestamp = timestamp
        }
    }

    public struct HeadPose {
        public let pitch: Float
        public let yaw: Float
        public let roll: Float

        public init(pitch: Float, yaw: Float, roll: Float) {
            self.pitch = pitch
            self.yaw = yaw
            self.roll = roll
        }
    }

    public struct CalibrationData: Codable {
        public var offsetX: Float
        public var offsetY: Float
        public var scaleX: Float
        public var scaleY: Float
        public var rotationCompensation: Float

        public init(
            offsetX: Float = 0,
            offsetY: Float = 0,
            scaleX: Float = 1,
            scaleY: Float = 1,
            rotationCompensation: Float = 0
        ) {
            self.offsetX = offsetX
            self.offsetY = offsetY
            self.scaleX = scaleX
            self.scaleY = scaleY
            self.rotationCompensation = rotationCompensation
        }
    }

    private let smoothingFactor: Float = 0.3
    private let blinkThreshold: Float = 0.3
    private let velocityThreshold: Float = 100.0

    private var lastGazePoint: CGPoint?
    private var calibrationData: CalibrationData?
    private var isCalibrated: Bool = false
    private var kalmanFilter: KalmanFilter
    private let performanceMonitor: PerformanceMonitor

    private lazy var faceDetectionRequest: VNDetectFaceLandmarksRequest = {
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        return request
    }()

    public init() {
        self.kalmanFilter = KalmanFilter()
        self.performanceMonitor = PerformanceMonitor()
    }

    public func calculateGazePoint(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) -> GazeResult? {
        let startTime = performanceMonitor.startFrame()
        defer {
            performanceMonitor.endFrame(startTime: startTime)
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )

        do {
            try handler.perform([faceDetectionRequest])
            guard let faceObservation = faceDetectionRequest.results?.first else {
                return nil
            }
            return processGaze(from: faceObservation)
        } catch {
            return nil
        }
    }

    public func calibrate(calibrationPoints: [(expected: CGPoint, actual: CGPoint)]) {
        guard calibrationPoints.count >= 3 else { return }

        var sumOffsetX: Float = 0
        var sumOffsetY: Float = 0
        var sumScaleX: Float = 0
        var sumScaleY: Float = 0

        for (expected, actual) in calibrationPoints {
            sumOffsetX += Float(expected.x - actual.x)
            sumOffsetY += Float(expected.y - actual.y)
            if actual.x != 0 {
                sumScaleX += Float(expected.x / actual.x)
            }
            if actual.y != 0 {
                sumScaleY += Float(expected.y / actual.y)
            }
        }

        let count = Float(calibrationPoints.count)
        calibrationData = CalibrationData(
            offsetX: sumOffsetX / count,
            offsetY: sumOffsetY / count,
            scaleX: sumScaleX / count,
            scaleY: sumScaleY / count
        )
        isCalibrated = true
    }

    public func resetCalibration() {
        calibrationData = nil
        isCalibrated = false
        lastGazePoint = nil
        kalmanFilter.reset()
    }

    public func getPerformanceMetrics() -> PerformanceMonitor.PerformanceMetrics {
        return performanceMonitor.getMetrics()
    }

    private func processGaze(from faceObservation: VNFaceObservation) -> GazeResult? {
        guard let landmarks = faceObservation.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            return nil
        }

        let isBlinking = detectBlink(leftEye: leftEye, rightEye: rightEye)
        let headPose = calculateHeadPose(from: faceObservation)
        let gazeVector = calculateGazeVector(
            leftEye: leftEye,
            rightEye: rightEye,
            headPose: headPose
        )
        let calibratedVector = applyCalibration(to: gazeVector)
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1440, height: 900)
        let screenPoint = mapGazeVectorToScreen(
            gazeVector: calibratedVector,
            headPose: headPose,
            screenSize: screenSize
        )
        let filteredPoint = kalmanFilter.update(measurement: screenPoint)
        let smoothedPoint = applyAdaptiveSmoothing(currentPoint: filteredPoint)
        let confidence = calculateConfidence(
            faceObservation: faceObservation,
            isBlinking: isBlinking
        )
        lastGazePoint = smoothedPoint

        return GazeResult(
            gazePoint: smoothedPoint,
            confidence: confidence,
            isBlinking: isBlinking,
            headPose: headPose,
            timestamp: Date().timeIntervalSince1970
        )
    }

    private func calculateGazeVector(
        leftEye: VNFaceLandmarkRegion2D,
        rightEye: VNFaceLandmarkRegion2D,
        headPose: HeadPose
    ) -> CGPoint {
        let leftPoints = leftEye.normalizedPoints
        let rightPoints = rightEye.normalizedPoints
        guard !leftPoints.isEmpty, !rightPoints.isEmpty else { return .zero }

        let leftCenter = averagePoint(points: leftPoints)
        let rightCenter = averagePoint(points: rightPoints)

        var gazeX = rightCenter.x - leftCenter.x
        var gazeY = rightCenter.y - leftCenter.y
        gazeX += CGFloat(headPose.yaw) * 0.005
        gazeY += CGFloat(headPose.pitch) * 0.005

        let magnitude = sqrt(gazeX * gazeX + gazeY * gazeY)
        if magnitude > 0 {
            gazeX /= magnitude
            gazeY /= magnitude
        }
        return CGPoint(x: gazeX, y: gazeY)
    }

    private func calculateHeadPose(from faceObservation: VNFaceObservation) -> HeadPose {
        HeadPose(
            pitch: faceObservation.pitch?.floatValue ?? 0,
            yaw: faceObservation.yaw?.floatValue ?? 0,
            roll: faceObservation.roll?.floatValue ?? 0
        )
    }

    private func detectBlink(
        leftEye: VNFaceLandmarkRegion2D,
        rightEye: VNFaceLandmarkRegion2D
    ) -> Bool {
        let avgEAR = (calculateEyeAspectRatio(eye: leftEye) + calculateEyeAspectRatio(eye: rightEye)) / 2
        return avgEAR < blinkThreshold
    }

    private func calculateEyeAspectRatio(eye: VNFaceLandmarkRegion2D) -> Float {
        let points = eye.normalizedPoints
        guard points.count >= 6 else { return 1.0 }
        let vertical1 = distance(from: points[1], to: points[5])
        let vertical2 = distance(from: points[2], to: points[4])
        let horizontal = distance(from: points[0], to: points[3])
        if horizontal == 0 { return 1.0 }
        return Float((vertical1 + vertical2) / (2.0 * horizontal))
    }

    private func mapGazeVectorToScreen(
        gazeVector: CGPoint,
        headPose: HeadPose,
        screenSize: CGSize
    ) -> CGPoint {
        let yawFactor: CGFloat = 1.0 + (CGFloat(abs(headPose.yaw)) / 30.0) * 0.2
        let pitchFactor: CGFloat = 1.0 + (CGFloat(abs(headPose.pitch)) / 30.0) * 0.2
        var screenX = (screenSize.width / 2) + (gazeVector.x * (screenSize.width / 2) * yawFactor)
        var screenY = (screenSize.height / 2) - (gazeVector.y * (screenSize.height / 2) * pitchFactor)
        screenX = max(0, min(screenSize.width, screenX))
        screenY = max(0, min(screenSize.height, screenY))
        return CGPoint(x: screenX, y: screenY)
    }

    private func applyCalibration(to gazeVector: CGPoint) -> CGPoint {
        guard isCalibrated, let calibration = calibrationData else {
            return gazeVector
        }
        return CGPoint(
            x: CGFloat(gazeVector.x * CGFloat(calibration.scaleX) + CGFloat(calibration.offsetX)),
            y: CGFloat(gazeVector.y * CGFloat(calibration.scaleY) + CGFloat(calibration.offsetY))
        )
    }

    private func applyAdaptiveSmoothing(currentPoint: CGPoint) -> CGPoint {
        guard let lastPoint = lastGazePoint else { return currentPoint }
        let dx = currentPoint.x - lastPoint.x
        let dy = currentPoint.y - lastPoint.y
        let velocity = sqrt(dx * dx + dy * dy)
        let adaptiveFactor: CGFloat = velocity > CGFloat(velocityThreshold)
            ? CGFloat(smoothingFactor) * 0.5
            : CGFloat(smoothingFactor)
        return CGPoint(
            x: lastPoint.x + (currentPoint.x - lastPoint.x) * adaptiveFactor,
            y: lastPoint.y + (currentPoint.y - lastPoint.y) * adaptiveFactor
        )
    }

    private func calculateConfidence(
        faceObservation: VNFaceObservation,
        isBlinking: Bool
    ) -> Float {
        var confidence = faceObservation.confidence
        if isBlinking {
            confidence *= 0.3
        }
        let faceArea = faceObservation.boundingBox.width * faceObservation.boundingBox.height
        if faceArea < 0.05 {
            confidence *= 0.7
        }
        return max(0, min(1, confidence))
    }

    private func averagePoint(points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for point in points {
            sumX += point.x
            sumY += point.y
        }
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }

    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
}
