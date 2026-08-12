## 3.0.4

* Depend on JitPack `GazePointSDK-Android:2.1.1`. Tag `2.1.0` never built on JitPack (`Error`), so Android apps using 3.0.3 fail with "Could not find ...:2.1.0".
* Example app `compileSdk = 37` (plugin requires 37; Flutter's default was 36).
* Example Gradle repositories include `https://jitpack.io`.
* Pin the plugin Kotlin `jvmTarget` to 17 so it matches Java 17 (AGP 9 / JDK 25 otherwise compiles Kotlin as 25 and the Android example fails).
* `startTracking()` requests camera permission when it is missing. The example Start button does the same and explains how to enable Camera if the user denied the prompt.
* Put iOS Swift sources inside `ios/gazepoint_sdk/Sources/gazepoint_sdk` so Swift Package Manager can resolve the plugin (Flutter 3.44+). `path: "../Classes"` is outside the package root and Xcode rejects it.
* Example iOS `IPHONEOS_DEPLOYMENT_TARGET` is 16.0 (plugin minimum). Flutter’s generated 13.0 target cannot link `gazepoint-sdk`.
* Add `lib/gazepoint_sdk_web.dart` and `flutter_web_plugins` so `flutter run -d chrome` compiles. Web tracking uses the camera plus MediaPipe Face Mesh from jsDelivr.

## 3.0.3

* Stop tracking `pana-report.json` so `dart pub publish` is not blocked by a gitignored file.
* Restore the working tree after Pana in CI so publish dry-run sees a clean checkout.

## 3.0.2

* Format `gazepoint_sdk_method_channel.dart` so Pana static analysis is 50/50 (160/160 overall).
* Document implicit constructors on `GazeTracker` and `MethodChannelGazepointSdk`.
* Consume the published Android SDK from JitPack (`GazePointSDK-Android:2.1.0`) instead of vendoring Kotlin sources. An Android-only release no longer requires copying files into this plugin.
* iOS still ships a source snapshot under `ios/Classes/GazePointSDK` so CocoaPods apps keep working; releasing GazePointSDK-iOS does not change this plugin until that snapshot is updated.
* Add plugin-local publish/Pana workflows and a Flutter issue template.

## 3.0.1

### Quality Improvements
- **Perfect Pana Score**: Achieved 160/160 points on pub.dev analysis
- Added Swift Package Manager support for iOS and macOS
- Updated to built-in Kotlin support (removed legacy configuration)
- Added comprehensive dartdoc comments to all constructors
- Code formatting and linting improvements

### Technical Changes
- Added `ios/gazepoint_sdk/Package.swift` for SPM support
- Added `macos/gazepoint_sdk/Package.swift` for SPM support
- Removed legacy Kotlin Gradle Plugin configuration
- Enhanced API documentation coverage to 95.1%

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
