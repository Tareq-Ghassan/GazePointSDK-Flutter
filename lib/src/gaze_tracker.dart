import 'package:flutter/foundation.dart';

import 'models/gaze_calibration_point.dart';
import 'models/gaze_tracker_options.dart';
import 'gazepoint_sdk_platform_interface.dart';
import 'models/gaze_result.dart';
import 'models/performance_metrics.dart';

/// Main GazeTracker class for Flutter applications.
///
/// Wraps Android, iOS, and macOS via platform channels, and web via
/// `GazepointSdkWeb` (camera + MediaPipe Face Mesh).
///
/// Metrics-only:
/// ```dart
/// final gazeTracker = GazeTracker();
/// await gazeTracker.initialize();
/// await gazeTracker.startTracking();
/// gazeTracker.gazeStream.listen((result) { ... });
/// ```
///
/// With live preview (opt-in):
/// ```dart
/// await gazeTracker.initialize(
///   options: GazeTrackerOptions(previewEnabled: true),
/// );
/// // In the widget tree: GazePreview(tracker: gazeTracker)
/// ```
class GazeTracker {
  /// Creates a gaze tracker that talks to the current platform implementation.
  GazeTracker();

  final GazepointSdkPlatform _platform = GazepointSdkPlatform.instance;

  bool _isInitialized = false;
  bool _isTracking = false;
  GazeTrackerOptions _options = const GazeTrackerOptions();

  /// Whether a [GazePreview] surface should be bound.
  ///
  /// Apps can listen to this to rebuild when [setPreviewEnabled] changes.
  final ValueNotifier<bool> previewEnabled = ValueNotifier<bool>(false);

  /// Last options passed to [initialize] / [setPreviewEnabled].
  GazeTrackerOptions get options => _options;

  /// Whether the tracker is initialized
  bool get isInitialized => _isInitialized;

  /// Whether tracking is currently active
  bool get isTracking => _isTracking;

  /// Initialize the gaze tracker.
  ///
  /// Must be called before starting tracking. Pass
  /// [GazeTrackerOptions.previewEnabled] true if the app will show
  /// [GazePreview]; leave it false to only receive gaze metrics.
  Future<void> initialize({
    GazeTrackerOptions options = const GazeTrackerOptions(),
  }) async {
    if (_isInitialized) {
      throw StateError('GazeTracker is already initialized');
    }

    _options = options;
    previewEnabled.value = options.previewEnabled;
    await _platform.initialize(options: options);
    _isInitialized = true;
  }

  /// Start gaze tracking.
  ///
  /// Requires [initialize] to be called first.
  /// Requests camera permission if it has not been granted yet.
  Future<void> startTracking() async {
    if (!_isInitialized) {
      throw StateError('GazeTracker not initialized. Call initialize() first.');
    }

    if (_isTracking) {
      throw StateError('Tracking is already active');
    }

    if (!await hasCameraPermission()) {
      final granted = await requestCameraPermission();
      if (!granted) {
        throw StateError(
          'Camera permission not granted. Allow camera for this app in system settings, then try again.',
        );
      }
    }

    await _platform.startTracking();
    _isTracking = true;
  }

  /// Stop gaze tracking
  Future<void> stopTracking() async {
    if (!_isTracking) {
      return;
    }

    await _platform.stopTracking();
    _isTracking = false;
  }

  /// Enable or disable the live camera preview at runtime.
  ///
  /// Tracking (metrics) keeps running. When disabled, [GazePreview] shows
  /// a black surface and the camera analysis pipeline stays headless.
  Future<void> setPreviewEnabled(bool enabled) async {
    if (!_isInitialized) {
      throw StateError('GazeTracker not initialized');
    }
    _options = _options.copyWith(previewEnabled: enabled);
    previewEnabled.value = enabled;
    await _platform.setPreviewEnabled(enabled);
  }

  /// Switch between the front and back cameras.
  Future<void> switchCamera() async {
    if (!_isInitialized) {
      throw StateError('GazeTracker not initialized');
    }
    await _platform.switchCamera();
  }

  /// Get the latest gaze result.
  ///
  /// Returns null if no gaze data is available.
  Future<GazeResult?> getLatestGaze() async {
    if (!_isInitialized) {
      throw StateError('GazeTracker not initialized');
    }

    return await _platform.getLatestGaze();
  }

  /// Calibrate with expected/actual screen point pairs.
  ///
  /// Matches the native SDK APIs: each entry is where the user was asked to
  /// look ([GazeCalibrationPoint.expected]) and where the tracker measured
  /// ([GazeCalibrationPoint.actual]). At least 3 points are required.
  Future<void> calibrate(List<GazeCalibrationPoint> calibrationPoints) async {
    if (!_isInitialized) {
      throw StateError('GazeTracker not initialized');
    }

    if (calibrationPoints.length < 3) {
      throw ArgumentError('At least 3 calibration points are required');
    }

    await _platform.calibrate(calibrationPoints);
  }

  /// Reset calibration to default
  Future<void> resetCalibration() async {
    if (!_isInitialized) {
      throw StateError('GazeTracker not initialized');
    }

    await _platform.resetCalibration();
  }

  /// Get current performance metrics
  Future<PerformanceMetrics> getPerformanceMetrics() async {
    if (!_isInitialized) {
      throw StateError('GazeTracker not initialized');
    }

    return await _platform.getPerformanceMetrics();
  }

  /// Stream of gaze results.
  ///
  /// Provides real-time updates while tracking is active. Frames with no
  /// face still emit a [GazeResult] with [GazeResult.faceDetected] false.
  Stream<GazeResult> get gazeStream => _platform.gazeStream;

  /// Check if gaze tracking is supported on this device
  Future<bool> isSupported() async {
    return await _platform.isSupported();
  }

  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    return await _platform.hasCameraPermission();
  }

  /// Request camera permission from the user
  Future<bool> requestCameraPermission() async {
    return await _platform.requestCameraPermission();
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_isTracking) {
      await stopTracking();
    }
    previewEnabled.dispose();
    _isInitialized = false;
    _isTracking = false;
  }
}
