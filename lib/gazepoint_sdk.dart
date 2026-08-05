/// GazePoint SDK - Advanced eye tracking and gaze point detection for Flutter.
///
/// This library provides real-time eye tracking capabilities for Flutter applications
/// on Android and iOS platforms. It enables developers to understand where users are
/// looking on their screens, opening up possibilities for UX research, accessibility
/// features, engagement tracking, and innovative user interactions.
///
/// ## Features
///
/// - Real-time gaze tracking at 30 FPS with sub-100ms latency
/// - Head pose compensation for accurate tracking
/// - Blink detection using Eye Aspect Ratio
/// - Kalman filtering for smooth gaze point movement
/// - Multi-point calibration (3-9 calibration points)
/// - Performance monitoring (FPS, latency, dropped frames)
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:gazepoint_sdk/gazepoint_sdk.dart';
///
/// final gazeTracker = GazeTracker();
/// await gazeTracker.initialize();
/// await gazeTracker.startTracking();
///
/// gazeTracker.gazeStream.listen((result) {
///   print('Gaze: ${result.gazePoint}');
///   print('Confidence: ${result.confidence}');
/// });
/// ```
///
/// For detailed documentation, see:
/// https://github.com/Tareq-Ghassan/GazePointSDK-Flutter#readme
library gazepoint_sdk;

export 'src/gazepoint_sdk_platform_interface.dart';
export 'src/gazepoint_sdk_method_channel.dart';
export 'src/models/gaze_calibration_point.dart';
export 'src/models/gaze_result.dart';
export 'src/models/head_pose.dart';
export 'src/models/performance_metrics.dart';
export 'src/gaze_tracker.dart';
