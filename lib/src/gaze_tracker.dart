import 'models/gaze_calibration_point.dart';
import 'gazepoint_sdk_platform_interface.dart';
import 'models/gaze_result.dart';
import 'models/performance_metrics.dart';

/// Main GazeTracker class for Flutter applications.
///
/// Wraps the native Android / iOS GazePoint SDKs via platform channels.
///
/// Example usage:
/// ```dart
/// final gazeTracker = GazeTracker();
///
/// await gazeTracker.initialize();
///
/// if (await gazeTracker.isSupported() &&
///     await gazeTracker.requestCameraPermission()) {
///   await gazeTracker.startTracking();
///
///   gazeTracker.gazeStream.listen((result) {
///     print('Gaze at: ${result.gazePoint}');
///   });
/// }
/// ```
class GazeTracker {
  final GazepointSdkPlatform _platform = GazepointSdkPlatform.instance;

  bool _isInitialized = false;
  bool _isTracking = false;

  /// Whether the tracker is initialized
  bool get isInitialized => _isInitialized;

  /// Whether tracking is currently active
  bool get isTracking => _isTracking;

  /// Initialize the gaze tracker.
  ///
  /// Must be called before starting tracking.
  Future<void> initialize() async {
    if (_isInitialized) {
      throw StateError('GazeTracker is already initialized');
    }

    await _platform.initialize();
    _isInitialized = true;
  }

  /// Start gaze tracking.
  ///
  /// Requires [initialize] to be called first.
  /// Requires camera permission to be granted.
  Future<void> startTracking() async {
    if (!_isInitialized) {
      throw StateError('GazeTracker not initialized. Call initialize() first.');
    }

    if (_isTracking) {
      throw StateError('Tracking is already active');
    }

    if (!await hasCameraPermission()) {
      throw StateError('Camera permission not granted');
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
  /// Provides real-time updates while tracking is active.
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
    _isInitialized = false;
    _isTracking = false;
  }
}
