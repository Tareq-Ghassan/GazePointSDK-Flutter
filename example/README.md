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

Tap **Start Tracking** — the app requests camera permission. On the Android emulator, allow Camera when prompted (Extended controls → Camera can use the webcam or a virtual scene). If you already denied it, enable Camera in the app’s system settings.

See the umbrella [TESTING.md](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/blob/main/TESTING.md) for the full matrix.

## Platform Requirements

### Android
- Minimum SDK version: 24 (Android 7.0)
- compileSdk 37
- Java/Kotlin JVM target 17 (not the JDK 25 default)
- JitPack (`https://jitpack.io`) in `android/build.gradle.kts` repositories
- Camera permission required

### iOS
- Minimum iOS version: 16.0 on the **Runner target** and in `ios/Flutter/Debug.xcconfig` / `Release.xcconfig` (project-level alone is not enough for SwiftPM).
- Camera permission required
- Physical iPhone (camera). After a plugin SPM layout change, run `flutter clean` then `flutter run -d ios`.
- If Xcode says gazepoint-sdk requires 16.0 but the target supports 13.0: `flutter clean && flutter build ios --config-only`, then run again.
- Prefer a **USB** cable. Wireless debug (`Tareq’s iPhone (wireless)`) waits for the Dart VM Service on the local network. A white screen plus “Dart VM Service was not discovered” means the debugger never attached — the gaze SDK has not started yet. Tap **Allow** on Local Network (`Settings → Gazepoint Sdk Example → Local Network`). If you tapped Don’t Allow, uninstall the app and run again. To confirm the UI without a debugger: `flutter run -d ios --release`.

### Web
- Chrome (or another WebRTC browser). Allow the camera when prompted.
- `localhost` is a secure origin; HTTPS is not required for `flutter run -d chrome`.
- MediaPipe Face Mesh loads from jsDelivr — needs network access.
- A black preview with `unregistered_view_type: gazepoint_sdk/preview` means an old plugin build; hot-restart or `flutter run -d chrome` again so `registerViewFactory` runs.

### macOS
- Minimum macOS version: 13.0 (`MACOSX_DEPLOYMENT_TARGET` in `macos/Runner.xcodeproj`)
- Camera permission + `com.apple.security.device.camera` in entitlements (already set)
- Allow Camera in System Settings if prompted. After a plugin SPM layout change, run `flutter clean` then `flutter run -d macos`.
- Windows / Linux still fail until those plugin implementations exist.

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
<key>NSLocalNetworkUsageDescription</key>
<string>Allow Flutter tools on this Mac to connect and debug the app over the local network.</string>
<key>NSBonjourServices</key>
<array>
  <string>_dartVmService._tcp</string>
  <string>_dartobservatory._tcp</string>
</array>
```

### macOS (`macos/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for eye tracking</string>
```

## Learn More

For more detailed documentation and advanced usage, see:
- [GazePoint SDK Flutter Documentation](https://github.com/Tareq-Ghassan/GazePointSDK-Flutter)
- [Main Repository](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint)
