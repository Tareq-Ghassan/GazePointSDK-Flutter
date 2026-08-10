## 3.0.0

**Major Release: Universal Platform Support** 🎉

* **New Platforms:**
  * ✅ Web support with MediaPipe Face Mesh and TensorFlow.js
  * ✅ Windows support with Windows.Media.FaceAnalysis and ML.NET
  * ✅ macOS support with Vision Framework and AVFoundation
  * ✅ Linux support with OpenCV, dlib, and V4L2
* **Enhanced Documentation:**
  * Comprehensive README with all platforms
  * Platform-specific setup guides
  * Complete API reference documentation
  * Troubleshooting section for all platforms
  * Performance optimization tips
* **Architecture:**
  * Unified API across all 6 platforms (Android, iOS, Web, Windows, macOS, Linux)
  * Native SDK implementations for each platform
  * Platform channels for seamless integration
  * Consistent 30 FPS performance target
* **Features:**
  * Real-time gaze tracking (30 FPS, <100ms latency)
  * Blink detection across all platforms
  * Head pose estimation (pitch, yaw, roll)
  * Kalman filtering for smooth tracking
  * Multi-point calibration (3, 5, or 9 points)
  * Performance monitoring and metrics
* **Examples:**
  * Updated Flutter example with multi-platform support
  * Platform-specific examples in main repository
  * Comprehensive usage documentation
* **Breaking Changes:**
  * Expanded platform support requires Flutter 3.38.4+
  * Some platform-specific behaviors may differ slightly
  * Calibration API remains compatible

## 2.1.0

* Improve pub.dev package score ([PR #3](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/pull/3)):
  * Document 100% of public API symbols (library docs, `GazeResult`, `GazeCalibrationPoint`)
  * Add complete plugin `example/` app with README and usage demo
  * Add iOS Swift Package Manager support (`ios/Package.swift`)
  * Migrate Android toward Flutter built-in Kotlin support
* Align multi-platform release versioning with umbrella tag `v2.1.0`

## 2.0.0

* Initial public release of the Flutter GazePoint plugin.
* Android + iOS platform channels with stream-based gaze updates.
* Camera permission helper, start/stop tracking, and multi-point calibration API.
* Wraps native GazePoint SDKs (ML Kit on Android, Vision on iOS).
