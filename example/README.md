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
flutter run
```

## Platform Requirements

### Android
- Minimum SDK version: 24 (Android 7.0)
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
