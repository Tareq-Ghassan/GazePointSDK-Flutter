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
