import AVFoundation
import Flutter
import GazePointSDK
import UIKit

/**
 Flutter plugin wrapper around the iOS GazePoint SDK.
 Owns AVCapture + Vision pipeline and delegates gaze math to GazeTracker.
 */
public class GazepointSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private var gazeTracker: GazeTracker?
    private var isInitialized = false
    private var isTracking = false
    private var latestResult: [String: Any]?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.gazepoint.flutter.camera")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var frameProcessor: FrameProcessor?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = GazepointSdkPlugin()

        let methodChannel = FlutterMethodChannel(
            name: "gazepoint_sdk",
            binaryMessenger: registrar.messenger()
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "gazepoint_sdk/gaze_stream",
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel = eventChannel
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            if gazeTracker == nil {
                gazeTracker = GazeTracker()
            }
            isInitialized = true
            result(nil)

        case "startTracking":
            guard isInitialized else {
                result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
                return
            }
            startCamera()
            result(nil)

        case "stopTracking":
            stopCamera()
            result(nil)

        case "getLatestGaze":
            result(latestResult)

        case "calibrate":
            guard let args = call.arguments as? [String: Any],
                  let rawPoints = args["calibrationPoints"] as? [[String: Any]],
                  rawPoints.count >= 3
            else {
                result(FlutterError(code: "INVALID_ARGS", message: "At least 3 calibration points required", details: nil))
                return
            }

            var points: [(expected: CGPoint, actual: CGPoint)] = []
            for map in rawPoints {
                guard let expected = map["expected"] as? [String: Any],
                      let actual = map["actual"] as? [String: Any],
                      let ex = expected["x"] as? NSNumber,
                      let ey = expected["y"] as? NSNumber,
                      let ax = actual["x"] as? NSNumber,
                      let ay = actual["y"] as? NSNumber
                else { continue }
                points.append((
                    expected: CGPoint(x: CGFloat(truncating: ex), y: CGFloat(truncating: ey)),
                    actual: CGPoint(x: CGFloat(truncating: ax), y: CGFloat(truncating: ay))
                ))
            }

            guard points.count >= 3 else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid calibration point format", details: nil))
                return
            }
            gazeTracker?.calibrate(calibrationPoints: points)
            result(nil)

        case "resetCalibration":
            gazeTracker?.resetCalibration()
            result(nil)

        case "getPerformanceMetrics":
            guard let tracker = gazeTracker else {
                result(FlutterError(code: "NOT_INITIALIZED", message: "Tracker not initialized", details: nil))
                return
            }
            let metrics = tracker.getPerformanceMetrics()
            result([
                "fps": Double(metrics.fps),
                "avgProcessingTimeMs": Double(metrics.avgProcessingTimeMs),
                "maxProcessingTimeMs": Double(metrics.maxProcessingTimeMs),
                "droppedFrames": metrics.droppedFrames,
                "totalFrames": metrics.totalFrames
            ])

        case "isSupported":
            result(UIImagePickerController.isSourceTypeAvailable(.camera))

        case "hasCameraPermission":
            result(AVCaptureDevice.authorizationStatus(for: .video) == .authorized)

        case "requestCameraPermission":
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                result(true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async { result(granted) }
                }
            default:
                result(false)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func startCamera() {
        if isTracking { return }

        let tracker = gazeTracker ?? GazeTracker()
        gazeTracker = tracker

        let processor = FrameProcessor(tracker: tracker) { [weak self] gazeResult in
            guard let self else { return }
            let mapped = gazeResult.map { self.toMap($0) }
            self.latestResult = mapped
            DispatchQueue.main.async {
                self.eventSink?(mapped)
            }
        }
        frameProcessor = processor

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureSession(processor: processor)
            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.isTracking = true
        }
    }

    private func stopCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.isTracking = false
        }
    }

    private func configureSession(processor: FrameProcessor) {
        session.beginConfiguration()
        session.sessionPreset = .high

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            return
        }

        session.addOutput(videoOutput)
        videoOutput.setSampleBufferDelegate(
            processor,
            queue: DispatchQueue(label: "com.gazepoint.flutter.frames")
        )

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }

        session.commitConfiguration()
    }

    private func toMap(_ result: GazeTracker.GazeResult) -> [String: Any] {
        return [
            "gazePointX": Double(result.gazePoint.x),
            "gazePointY": Double(result.gazePoint.y),
            "confidence": Double(result.confidence),
            "isBlinking": result.isBlinking,
            "headPose": [
                "pitch": Double(result.headPose.pitch),
                "yaw": Double(result.headPose.yaw),
                "roll": Double(result.headPose.roll)
            ],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
    }
}

/// Runs off the main thread so camera callbacks stay non-blocking.
final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let tracker: GazeTracker
    private let onResult: (GazeTracker.GazeResult?) -> Void

    init(tracker: GazeTracker, onResult: @escaping (GazeTracker.GazeResult?) -> Void) {
        self.tracker = tracker
        self.onResult = onResult
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let result = tracker.calculateGazePoint(from: pixelBuffer, orientation: .leftMirrored)
        onResult(result)
    }
}
