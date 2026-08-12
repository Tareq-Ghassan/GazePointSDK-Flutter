# gazepoint_sdk_example

Demonstrates how to use the gazepoint_sdk plugin for real-time eye tracking and gaze point detection.

## Getting started

This example app shows the basic usage of the GazePoint SDK:

1. Initializing the gaze tracker
2. Starting and stopping tracking
3. Listening to gaze point updates
4. Displaying the gaze point on screen

## Features demonstrated

- Real-time gaze point tracking
- Confidence score display
- Blink detection
- Visual gaze point indicator

## Running the example

```bash
cd example
flutter pub get
flutter run                 # picks a connected device
flutter run -d macos
flutter run -d chrome
flutter run -d android
flutter run -d ios
```

This example depends on the **local plugin** (`path: ../`), not pub.dev. After 3.0.4, app users should pin `gazepoint_sdk: ^3.0.4` (3.0.3 Android builds fail because JitPack has no `2.1.0` artifact).

See the umbrella [TESTING.md](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/blob/main/TESTING.md) for the full matrix.

## Platform Requirements

### Android
- Minimum SDK version: 24 (Android 7.0)
- compileSdk 37
- JitPack (`https://jitpack.io`) in `android/build.gradle.kts` repositories
- Camera permission required

### iOS
- Minimum iOS version: 16.0
- Camera permission required

## Permissions

Make sure to add camera permissions in your platform-specific configuration files:

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for eye tracking</string>
```

## Learn More

For more detailed documentation and advanced usage, see:
- [GazePoint SDK Flutter Documentation](https://github.com/Tareq-Ghassan/GazePointSDK-Flutter)
- [Main Repository](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint)
