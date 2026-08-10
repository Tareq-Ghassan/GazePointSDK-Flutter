# GazePoint SDK for Flutter

[![pub package](https://img.shields.io/pub/v/gazepoint_sdk.svg)](https://pub.dev/packages/gazepoint_sdk)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios%20%7C%20web%20%7C%20windows%20%7C%20macos%20%7C%20linux-blue)](https://pub.dev/packages/gazepoint_sdk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Advanced cross-platform Flutter plugin for **real-time eye tracking and gaze point detection**. Works seamlessly across all major platforms with native performance.

## ✨ Features

- 🎯 **Real-time Gaze Tracking** - 30 FPS with sub-100ms latency
- 👁️ **Blink Detection** - Automatic eye blink recognition
- 🎭 **Head Pose Estimation** - Track pitch, yaw, and roll angles
- 🎨 **Kalman Filtering** - Smooth gaze point tracking
- 📐 **Multi-Point Calibration** - 3, 5, or 9-point calibration support
- 📊 **Performance Metrics** - FPS, latency, and accuracy statistics
- 🌍 **Universal Platform Support** - One API, all platforms

## 🖥️ Platform Support

| Platform | Support | Technology | Min Version |
|----------|---------|------------|-------------|
| 🤖 Android | ✅ Full | ML Kit Face Detection + CameraX | API 24+ |
| 🍎 iOS | ✅ Full | Vision Framework + AVFoundation | iOS 16.0+ |
| 🌐 Web | ✅ Full | MediaPipe Face Mesh + TensorFlow.js | Modern browsers |
| 🪟 Windows | ✅ Full | Windows.Media.FaceAnalysis + ML.NET | Windows 10+ |
| 🖥️ macOS | ✅ Full | Vision Framework + AVFoundation | macOS 12.0+ |
| 🐧 Linux | ✅ Full | OpenCV + dlib + V4L2 | Ubuntu 20.04+ |

**Note:** Camera permission is required on all platforms.

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  gazepoint_sdk: ^3.0.0
```

Then install:

```bash
flutter pub get
```

## 🚀 Quick Start

```dart
import 'package:gazepoint_sdk/gazepoint_sdk.dart';

// Initialize the tracker
final tracker = GazeTracker();
await tracker.initialize();

// Request camera permission
if (await tracker.requestCameraPermission()) {
  // Start tracking
  await tracker.startTracking();
  
  // Listen to gaze events
  tracker.gazeStream.listen((result) {
    print('Gaze: ${result.gazePoint}');
    print('Confidence: ${result.confidence}');
    print('Blinking: ${result.isBlinking}');
    print('Head Pose: ${result.headPose}');
  });
}

// Stop tracking when done
await tracker.stopTracking();
await tracker.dispose();
```

## 📚 Complete Example

See the full example with UI in [`example/lib/main.dart`](example/lib/main.dart):

```dart
import 'package:flutter/material.dart';
import 'package:gazepoint_sdk/gazepoint_sdk.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GazeTracker _tracker = GazeTracker();
  GazeResult? _latestGaze;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _initializeTracker();
  }

  Future<void> _initializeTracker() async {
    await _tracker.initialize();
    
    _tracker.gazeStream.listen((result) {
      setState(() => _latestGaze = result);
    });
  }

  Future<void> _startTracking() async {
    final hasPermission = await _tracker.requestCameraPermission();
    if (hasPermission) {
      await _tracker.startTracking();
      setState(() => _isTracking = true);
    }
  }

  Future<void> _stopTracking() async {
    await _tracker.stopTracking();
    setState(() => _isTracking = false);
  }

  Future<void> _calibrate() async {
    // Collect calibration points (at least 3)
    final points = [
      GazeCalibrationPoint(
        expected: Offset(100, 100),
        actual: _latestGaze?.gazePoint ?? Offset.zero,
      ),
      // Add more calibration points...
    ];
    
    await _tracker.calibrate(points);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('GazePoint SDK Demo')),
        body: Stack(
          children: [
            // Your content here
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Gaze X: ${_latestGaze?.gazePoint.dx.toStringAsFixed(0) ?? "-"}'),
                  Text('Gaze Y: ${_latestGaze?.gazePoint.dy.toStringAsFixed(0) ?? "-"}'),
                  Text('Confidence: ${(_latestGaze?.confidence ?? 0) * 100}%'),
                  Text('Blinking: ${_latestGaze?.isBlinking ?? false}'),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isTracking ? _stopTracking : _startTracking,
                    child: Text(_isTracking ? 'Stop' : 'Start Tracking'),
                  ),
                  ElevatedButton(
                    onPressed: _isTracking ? _calibrate : null,
                    child: Text('Calibrate'),
                  ),
                ],
              ),
            ),
            
            // Gaze point indicator
            if (_latestGaze != null)
              Positioned(
                left: _latestGaze!.gazePoint.dx - 10,
                top: _latestGaze!.gazePoint.dy - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }
}
```

## 🔧 Platform-Specific Setup

### Android

**Minimum SDK:** API 24 (Android 7.0)

Camera permission is automatically declared by the plugin. Request it at runtime:

```dart
await tracker.requestCameraPermission();
```

**Optional:** Add to `android/app/build.gradle` for ProGuard:

```gradle
buildTypes {
    release {
        minifyEnabled true
        proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
    }
}
```

### iOS

**Minimum Version:** iOS 16.0

Add camera permission to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for eye tracking and gaze detection</string>
```

### Web

**Requirements:** Modern browser with WebRTC support

Served via **HTTPS** (required for camera access):

```bash
flutter run -d chrome --web-hostname localhost --web-port 8080
```

**Supported Browsers:**
- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

### Windows

**Minimum Version:** Windows 10 (build 1903+)

Camera permissions are managed by Windows Settings. The app will prompt when needed.

### macOS

**Minimum Version:** macOS 12.0 (Monterey)

Add camera permission to `macos/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for eye tracking and gaze detection</string>
```

Enable camera in **System Preferences → Security & Privacy → Privacy → Camera**

### Linux

**Minimum Requirements:**
- Ubuntu 20.04+ / Debian 11+ / Fedora 35+
- OpenCV 4.x
- V4L2 (Video4Linux2)

Install dependencies:

```bash
sudo apt-get install libopencv-dev v4l-utils
```

Grant camera permissions:

```bash
sudo usermod -a -G video $USER
# Log out and back in
```

## 📖 API Reference

### GazeTracker

Main class for eye tracking operations.

```dart
final tracker = GazeTracker();
```

#### Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `initialize()` | Initialize the tracker | `Future<void>` |
| `startTracking()` | Start gaze tracking | `Future<void>` |
| `stopTracking()` | Stop gaze tracking | `Future<void>` |
| `requestCameraPermission()` | Request camera access | `Future<bool>` |
| `calibrate(points)` | Calibrate with points | `Future<void>` |
| `dispose()` | Clean up resources | `Future<void>` |

#### Streams

| Stream | Description | Type |
|--------|-------------|------|
| `gazeStream` | Real-time gaze data | `Stream<GazeResult>` |

### GazeResult

Contains gaze tracking data.

```dart
class GazeResult {
  final Offset gazePoint;      // Screen coordinates
  final double confidence;      // 0.0 to 1.0
  final bool isBlinking;        // Blink detection
  final HeadPose headPose;      // Head orientation
  final int timestamp;          // Milliseconds since epoch
}
```

### HeadPose

Head orientation angles in degrees.

```dart
class HeadPose {
  final double pitch;  // Up/down rotation
  final double yaw;    // Left/right rotation
  final double roll;   // Tilt rotation
}
```

### GazeCalibrationPoint

Calibration point mapping.

```dart
class GazeCalibrationPoint {
  final Offset expected;  // Where user should look
  final Offset actual;    // Where tracker detected
}
```

## 🎯 Calibration

For best accuracy, calibrate with 5-9 points:

```dart
final calibrationPoints = [
  // Top-left
  GazeCalibrationPoint(
    expected: Offset(screenWidth * 0.1, screenHeight * 0.1),
    actual: currentGaze.gazePoint,
  ),
  // Top-right
  GazeCalibrationPoint(
    expected: Offset(screenWidth * 0.9, screenHeight * 0.1),
    actual: currentGaze.gazePoint,
  ),
  // Center
  GazeCalibrationPoint(
    expected: Offset(screenWidth * 0.5, screenHeight * 0.5),
    actual: currentGaze.gazePoint,
  ),
  // Bottom-left
  GazeCalibrationPoint(
    expected: Offset(screenWidth * 0.1, screenHeight * 0.9),
    actual: currentGaze.gazePoint,
  ),
  // Bottom-right
  GazeCalibrationPoint(
    expected: Offset(screenWidth * 0.9, screenHeight * 0.9),
    actual: currentGaze.gazePoint,
  ),
];

await tracker.calibrate(calibrationPoints);
```

## ⚡ Performance

Expected performance metrics:

| Metric | Value | Platform Variance |
|--------|-------|-------------------|
| Frame Rate | 30 FPS | ±5 FPS |
| Latency | 50-100ms | Lower on desktop |
| Accuracy | 1-2° visual angle | After calibration |
| CPU Usage | 8-15% | Varies by device |
| Memory | 100-200 MB | Depends on resolution |

**Optimization Tips:**
- Run calibration in good lighting
- Position camera 50-80cm from face
- Ensure face is centered in frame
- Avoid glasses with reflections
- Use higher-end devices for best results

## 🔍 Troubleshooting

### Camera Not Working

**Android:**
- Check `AndroidManifest.xml` has camera permission
- Verify device has a front-facing camera
- Grant permission in app settings

**iOS/macOS:**
- Verify `Info.plist` has camera usage description
- Check System Preferences → Privacy → Camera
- Allow permission when prompted

**Web:**
- Use HTTPS (or localhost for testing)
- Check browser camera permissions
- Try a different browser

**Windows:**
- Check Windows Settings → Privacy → Camera
- Enable for the app
- Restart application

**Linux:**
- Run `ls /dev/video*` to verify camera
- Check user is in `video` group
- Test with `ffplay /dev/video0`

### Low Accuracy

1. **Run Calibration** - Improves accuracy by 50-80%
2. **Check Lighting** - Ensure face is well-lit
3. **Adjust Distance** - 50-80cm from camera
4. **Center Face** - Keep face in camera view
5. **Remove Glasses** - Or use anti-reflective coating

### Performance Issues

- Lower `targetFPS` if needed
- Close other camera apps
- Restart tracking periodically
- Check device resources

## 🏗️ Architecture

GazePoint SDK uses native implementations for each platform:

```
Flutter App
    ↓
GazePoint Flutter Plugin
    ↓
Platform Channels
    ↓
Native SDKs (Android, iOS, Web, Windows, macOS, Linux)
    ↓
Platform APIs (ML Kit, Vision, MediaPipe, OpenCV, etc.)
```

Each platform SDK is independently maintained:

- [GazePointSDK-Android](https://github.com/Tareq-Ghassan/GazePointSDK-Android) - Kotlin + ML Kit
- [GazePointSDK-iOS](https://github.com/Tareq-Ghassan/GazePointSDK-iOS) - Swift + Vision
- [GazePointSDK-Web](https://github.com/Tareq-Ghassan/GazePointSDK-Web) - TypeScript + MediaPipe
- [GazePointSDK-Windows](https://github.com/Tareq-Ghassan/GazePointSDK-Windows) - C# + ML.NET
- [GazePointSDK-macOS](https://github.com/Tareq-Ghassan/GazePointSDK-macOS) - Swift + Vision
- [GazePointSDK-Linux](https://github.com/Tareq-Ghassan/GazePointSDK-Linux) - C++ + OpenCV

## 📝 Examples

Comprehensive examples for all platforms:

- **[Flutter Example](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/tree/main/flutter_example)** - Cross-platform Flutter app
- **[Android Example](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/tree/main/android_example)** - Native Android app
- **[iOS Example](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/tree/main/ios_example)** - Native iOS app
- **[Web Example](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/tree/main/web_example)** - Browser-based demo
- **[Windows Example](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/tree/main/windows_example)** - Native Windows app
- **[macOS Example](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/tree/main/macos_example)** - Native macOS app
- **[Linux Example](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/tree/main/linux_example)** - Native Linux app

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](https://github.com/Tareq-Ghassan/GazePointSDK-Flutter/blob/main/CONTRIBUTING.md) for details.

## 📄 License

MIT License - Copyright (c) 2024-2026 Tareq Abu Saleh

See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- ML Kit team for Android face detection
- Apple Vision framework team
- MediaPipe team for web face tracking
- OpenCV community
- Flutter team for amazing cross-platform support

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/Tareq-Ghassan/GazePointSDK-Flutter/issues)
- **Discussions:** [GitHub Discussions](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/discussions)
- **Documentation:** [Full Docs](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint#readme)

## 🔗 Related Projects

- [FaceDetection-GazePoint](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint) - Main monorepo
- [Multi-Platform Architecture](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/blob/main/MULTI_PLATFORM_ARCHITECTURE.md)
- [Publishing Guide](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/blob/main/PUBLISHING_GUIDE.md)

---

**Made with ❤️ by [Tareq Ghassan](https://github.com/Tareq-Ghassan)**
