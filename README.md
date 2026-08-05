# GazePoint SDK for Flutter

Cross-platform Flutter plugin for eye tracking and gaze point detection on Android and iOS.

**Repository:** [Tareq-Ghassan/GazePointSDK-Flutter](https://github.com/Tareq-Ghassan/GazePointSDK-Flutter)  
**Package:** `gazepoint_sdk`

Native gaze math is **vendored** inside this plugin (Android Kotlin + iOS Swift), so the package is self-contained for pub.dev. Standalone native SDKs remain in:

- [GazePointSDK-Android](https://github.com/Tareq-Ghassan/GazePointSDK-Android)
- [GazePointSDK-iOS](https://github.com/Tareq-Ghassan/GazePointSDK-iOS)

## Installation

```yaml
dependencies:
  gazepoint_sdk: ^2.1.0
```

```bash
flutter pub get
```

### Android

- Min SDK **24**
- Camera permission is declared by the plugin; request it at runtime via `requestCameraPermission()`

### iOS

- Deployment target **iOS 16.0+**
- Add to `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for eye tracking</string>
```

## Quick start

```dart
import 'package:gazepoint_sdk/gazepoint_sdk.dart';

final tracker = GazeTracker();

await tracker.initialize();
if (await tracker.requestCameraPermission()) {
  await tracker.startTracking();
  tracker.gazeStream.listen((result) {
    print('Gaze: ${result.gazePoint}  confidence: ${result.confidence}');
  });
}
```

### Calibration

```dart
await tracker.calibrate([
  GazeCalibrationPoint(
    expected: Offset(100, 100),
    actual: latestGaze.gazePoint,
  ),
  // …at least 3 points
]);
```

## Example app

See the umbrella monorepo [`flutter_example`](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/tree/main/flutter_example):

```bash
cd flutter_example
flutter pub get
flutter run   # physical device; camera required
```

## Platform support

| Platform | Minimum |
|----------|---------|
| Android  | API 24  |
| iOS      | iOS 16  |
| Flutter  | 3.38.4+ |

## License

MIT — Copyright (c) 2024 Tareq Abu Saleh

## Support

- Issues: [GazePointSDK-Flutter](https://github.com/Tareq-Ghassan/GazePointSDK-Flutter/issues)
