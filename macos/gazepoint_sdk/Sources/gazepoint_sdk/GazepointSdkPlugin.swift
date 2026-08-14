import AVFoundation
import Cocoa
import FlutterMacOS

/**
 Flutter plugin wrapper around the macOS GazePoint SDK snapshot.
 Camera preview, face boxes, and tracking live in GazeCamera.
 */
@available(macOS 13.0, *)
public class GazepointSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private var camera: GazeCamera?
    private var isInitialized = false
    private var latestResult: [String: Any]?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = GazepointSdkPlugin()
        instance.camera = GazeCamera.create()
        instance.camera?.onFrame = { [weak instance] frame in
            let mapped = instance?.toMap(frame)
            instance?.latestResult = mapped
            DispatchQueue.main.async {
                instance?.eventSink?(mapped)
            }
        }

        let methodChannel = FlutterMethodChannel(
            name: "gazepoint_sdk",
            binaryMessenger: registrar.messenger
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "gazepoint_sdk/gaze_stream",
            binaryMessenger: registrar.messenger
        )
        instance.eventChannel = eventChannel
        eventChannel.setStreamHandler(instance)

        registrar.register(
            GazePreviewFactory(plugin: instance),
            withId: "gazepoint_sdk/preview"
        )
    }

    func previewView() -> GazePreviewView? {
        camera?.previewView
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            let args = call.arguments as? [String: Any]
            let previewEnabled = args?["previewEnabled"] as? Bool ?? false
            let showFaceBoxes = args?["showFaceBoxes"] as? Bool ?? true
            if camera == nil {
                let cam = GazeCamera.create()
                cam.onFrame = { [weak self] frame in
                    let mapped = self?.toMap(frame)
                    self?.latestResult = mapped
                    DispatchQueue.main.async {
                        self?.eventSink?(mapped)
                    }
                }
                camera = cam
            }
            camera?.options = GazeCameraOptions(
                previewEnabled: previewEnabled,
                showFaceBoxes: showFaceBoxes
            )
            isInitialized = true
            result(nil)

        case "startTracking":
            guard isInitialized, let camera else {
                result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
                return
            }
            camera.start()
            result(nil)

        case "stopTracking":
            camera?.stop()
            result(nil)

        case "setPreviewEnabled":
            let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
            camera?.previewEnabled = enabled
            result(nil)

        case "switchCamera":
            camera?.switchCamera()
            result(nil)

        case "getLatestGaze":
            result(latestResult)

        case "calibrate":
            guard let args = call.arguments as? [String: Any],
                  let rawPoints = args["calibrationPoints"] as? [[String: Any]],
                  rawPoints.count >= 3
            else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "At least 3 calibration points required",
                    details: nil
                ))
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
            camera?.calibrate(calibrationPoints: points)
            result(nil)

        case "resetCalibration":
            camera?.resetCalibration()
            result(nil)

        case "getPerformanceMetrics":
            guard let camera else {
                result(FlutterError(code: "NOT_INITIALIZED", message: "Tracker not initialized", details: nil))
                return
            }
            let metrics = camera.getPerformanceMetrics()
            result([
                "fps": Double(metrics.fps),
                "avgProcessingTimeMs": Double(metrics.avgProcessingTimeMs),
                "maxProcessingTimeMs": Double(metrics.maxProcessingTimeMs),
                "droppedFrames": metrics.droppedFrames,
                "totalFrames": metrics.totalFrames
            ])

        case "isSupported":
            result(AVCaptureDevice.default(for: .video) != nil)

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

    private func toMap(_ frame: GazeFrame) -> [String: Any] {
        var map: [String: Any] = [
            "faceDetected": frame.faceDetected,
            "faceCount": frame.faceCount,
            "statusText": frame.statusText,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let gaze = frame.gaze {
            map["gazePointX"] = Double(gaze.gazePoint.x)
            map["gazePointY"] = Double(gaze.gazePoint.y)
            map["confidence"] = Double(gaze.confidence)
            map["isBlinking"] = gaze.isBlinking
            map["headPose"] = [
                "pitch": Double(gaze.headPose.pitch),
                "yaw": Double(gaze.headPose.yaw),
                "roll": Double(gaze.headPose.roll)
            ]
        }
        return map
    }
}

@available(macOS 13.0, *)
final class GazePreviewFactory: NSObject, FlutterPlatformViewFactory {
    private weak var plugin: GazepointSdkPlugin?

    init(plugin: GazepointSdkPlugin) {
        self.plugin = plugin
        super.init()
    }

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        if let preview = plugin?.previewView() {
            preview.removeFromSuperview()
            preview.translatesAutoresizingMaskIntoConstraints = true
            preview.autoresizingMask = [.width, .height]
            preview.frame = container.bounds
            container.addSubview(preview)
        }
        return container
    }
}
