# GazePoint SDK for Flutter

Cross-platform Flutter **plugin wrapper** for the native GazePoint SDKs (Android + iOS).

This package does **not** reimplement gaze math. It depends on:

- [`../android/gazepoint-sdk`](../android/gazepoint-sdk) (ML Kit `Face` → gaze)
- [`../ios`](../ios) (Vision / `CVPixelBuffer` → gaze)

The plugin’s native layer owns camera capture + face detection (ported from the native examples) and calls into those SDKs.

## Layout

```text
flutter/             → this plugin
flutter_example/     → demo host app (path dependency)
android/gazepoint-sdk
ios/
```

## Installation (monorepo / path)

In your app `pubspec.yaml`:

```yaml
dependencies:
  gazepoint_sdk:
    path: ../flutter   # or your relative path
```

Then:

```bash
flutter pub get
```

### Android host wiring

In the app’s `android/settings.gradle(.kts)`, include the local SDK module (same as `android_example`):

```kotlin
include(":gazepoint-sdk")
project(":gazepoint-sdk").projectDir = file("../../android/gazepoint-sdk")
```

Declare camera permission in the app manifest. Min SDK **24**.

### iOS host wiring

In the app’s `ios/Podfile`:

```ruby
platform :ios, '16.0'
pod 'GazePointSDK', :path => '../../ios'
```

Add `NSCameraUsageDescription` to `Info.plist`.

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

Native SDKs take **expected/actual** pairs:

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

See [`../flutter_example`](../flutter_example) for a full demo (status panel, gaze indicator, calibration).

```bash
cd flutter_example
flutter pub get
flutter run   # physical device; camera required
```

## Platform support

| Platform | Minimum | Native SDK |
|----------|---------|------------|
| Android  | API 24  | `android/gazepoint-sdk` |
| iOS      | iOS 16  | `ios` (GazePointSDK) |

## License

MIT
