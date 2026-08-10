// Copyright (c) 2024-2026, Tareq Abu Saleh. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

/// GazePoint SDK - Advanced cross-platform eye tracking and gaze point detection for Flutter.
///
/// This library provides real-time eye tracking capabilities for Flutter applications
/// across **all major platforms**: Android, iOS, Web, Windows, macOS, and Linux.
/// It enables developers to understand where users are looking on their screens,
/// opening up possibilities for UX research, accessibility features, engagement
/// tracking, and innovative user interactions.
///
/// ## Platform Support
///
/// - **Android** (API 24+) - ML Kit Face Detection + CameraX
/// - **iOS** (16.0+) - Vision Framework + AVFoundation
/// - **Web** - MediaPipe Face Mesh + TensorFlow.js
/// - **Windows** (10+) - Windows.Media.FaceAnalysis + ML.NET
/// - **macOS** (12.0+) - Vision Framework + AVFoundation
/// - **Linux** (Ubuntu 20.04+) - OpenCV + dlib + V4L2
///
/// ## Features
///
/// - Real-time gaze tracking at 30 FPS with sub-100ms latency
/// - Head pose compensation for accurate tracking (pitch, yaw, roll)
/// - Blink detection using Eye Aspect Ratio
/// - Kalman filtering for smooth gaze point movement
/// - Multi-point calibration (3-9 calibration points)
/// - Performance monitoring (FPS, latency, dropped frames)
/// - Unified API across all platforms
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:gazepoint_sdk/gazepoint_sdk.dart';
///
/// final gazeTracker = GazeTracker();
/// await gazeTracker.initialize();
///
/// // Request camera permission
/// if (await gazeTracker.requestCameraPermission()) {
///   await gazeTracker.startTracking();
///
///   gazeTracker.gazeStream.listen((result) {
///     print('Gaze: ${result.gazePoint}');
///     print('Confidence: ${result.confidence}');
///     print('Blinking: ${result.isBlinking}');
///     print('Head Pose: ${result.headPose}');
///   });
/// }
/// ```
///
/// ## Calibration
///
/// For improved accuracy, calibrate with multiple points:
///
/// ```dart
/// await gazeTracker.calibrate([
///   GazeCalibrationPoint(
///     expected: Offset(100, 100),
///     actual: currentGaze.gazePoint,
///   ),
///   // Add 3-9 points for best results
/// ]);
/// ```
///
/// For detailed documentation, platform-specific setup, and examples, see:
/// https://github.com/Tareq-Ghassan/GazePointSDK-Flutter#readme
library;

export 'src/gazepoint_sdk_platform_interface.dart';
export 'src/gazepoint_sdk_method_channel.dart';
export 'src/models/gaze_calibration_point.dart';
export 'src/models/gaze_result.dart';
export 'src/models/head_pose.dart';
export 'src/models/performance_metrics.dart';
export 'src/gaze_tracker.dart';
