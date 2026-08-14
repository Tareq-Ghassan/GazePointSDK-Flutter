import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/gazepoint_sdk_platform_interface.dart';
import 'src/models/gaze_calibration_point.dart';
import 'src/models/gaze_result.dart';
import 'src/models/gaze_tracker_options.dart';
import 'src/models/head_pose.dart';
import 'src/models/performance_metrics.dart';

/// Web implementation of [GazepointSdkPlatform].
///
/// Uses `getUserMedia` for the camera and MediaPipe Face Mesh (CDN) for
/// landmarks. Flutter registers this class from `web_plugin_registrant.dart`.
class GazepointSdkWeb extends GazepointSdkPlatform {
  /// Registers this class as the default [GazepointSdkPlatform] on web.
  static void registerWith(Registrar registrar) {
    GazepointSdkPlatform.instance = GazepointSdkWeb();
  }

  static const _faceMeshCdn =
      'https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh@0.4.1633559619';

  final _gazeController = StreamController<GazeResult>.broadcast();
  web.HTMLVideoElement? _video;
  web.MediaStream? _stream;
  JSObject? _faceMesh;
  bool _initialized = false;
  bool _tracking = false;
  bool _scriptsLoaded = false;
  GazeResult? _latest;
  int _totalFrames = 0;
  int _droppedFrames = 0;
  double _avgMs = 0;
  double _maxMs = 0;
  DateTime _fpsWindowStart = DateTime.now();
  int _fpsWindowFrames = 0;
  double _fps = 0;
  double _smoothX = 0;
  double _smoothY = 0;
  bool _hasSmooth = false;
  final List<GazeCalibrationPoint> _calibration = [];

  @override
  Future<void> initialize({
    GazeTrackerOptions options = const GazeTrackerOptions(),
  }) async {
    await _ensureScripts();
    _video ??= web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.display = 'none';
    web.document.body?.append(_video!);
    _initialized = true;
  }

  @override
  Future<void> setPreviewEnabled(bool enabled) async {
    _video?.style.display = enabled ? 'block' : 'none';
  }

  @override
  Future<void> switchCamera() async {
    // Web uses the user-facing camera by default.
  }

  @override
  Future<void> startTracking() async {
    if (!_initialized) {
      throw StateError('Call initialize() first');
    }
    final video = _video!;
    _stream ??= await _openCamera();
    video.srcObject = _stream;
    await video.play().toDart;
    _faceMesh ??= _createFaceMesh();
    _tracking = true;
    _pump(video);
  }

  @override
  Future<void> stopTracking() async {
    _tracking = false;
    _video?.pause();
    _stopTracks();
  }

  @override
  Future<GazeResult?> getLatestGaze() async => _latest;

  @override
  Future<void> calibrate(List<GazeCalibrationPoint> calibrationPoints) async {
    _calibration
      ..clear()
      ..addAll(calibrationPoints);
  }

  @override
  Future<void> resetCalibration() async {
    _calibration.clear();
  }

  @override
  Future<PerformanceMetrics> getPerformanceMetrics() async {
    return PerformanceMetrics(
      fps: _fps,
      avgProcessingTimeMs: _avgMs,
      maxProcessingTimeMs: _maxMs,
      droppedFrames: _droppedFrames,
      totalFrames: _totalFrames,
    );
  }

  @override
  Stream<GazeResult> get gazeStream => _gazeController.stream;

  @override
  Future<bool> isSupported() async {
    return web.window.navigator.has('mediaDevices');
  }

  @override
  Future<bool> hasCameraPermission() async {
    if (_stream != null && _stream!.active) return true;
    try {
      final status = await web.window.navigator.permissions
          .query({'name': 'camera'}.jsify()! as JSObject)
          .toDart;
      return status.state == 'granted';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestCameraPermission() async {
    try {
      _stream ??= await _openCamera();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<web.MediaStream> _openCamera() {
    final constraints = web.MediaStreamConstraints(
      video: {'facingMode': 'user', 'width': 1280, 'height': 720}.jsify()!,
    );
    return web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
  }

  void _stopTracks() {
    final stream = _stream;
    if (stream == null) return;
    final tracks = stream.getTracks().toDart;
    for (final track in tracks) {
      track.stop();
    }
    _stream = null;
    _video?.srcObject = null;
  }

  Future<void> _ensureScripts() async {
    if (_scriptsLoaded) return;
    if (!globalContext.has('FaceMesh')) {
      await _loadScript('$_faceMeshCdn/face_mesh.js');
    }
    if (!globalContext.has('FaceMesh')) {
      throw StateError(
        'MediaPipe Face Mesh failed to load from $_faceMeshCdn. '
        'Check the network tab and that the page is http://localhost or HTTPS.',
      );
    }
    _scriptsLoaded = true;
  }

  Future<void> _loadScript(String src) {
    final done = Completer<void>();
    final script = web.HTMLScriptElement()
      ..src = src
      ..async = true;
    script.onLoad.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    script.onError.listen((_) {
      if (!done.isCompleted) {
        done.completeError(StateError('Failed to load $src'));
      }
    });
    web.document.head!.append(script);
    return done.future;
  }

  JSObject _createFaceMesh() {
    final locateFile = ((JSString file) {
      return '$_faceMeshCdn/${file.toDart}'.toJS;
    }).toJS;
    final config = JSObject()..setProperty('locateFile'.toJS, locateFile);
    final mesh = _FaceMesh(config);
    mesh.setOptions(
      {
        'maxNumFaces': 1,
        'refineLandmarks': true,
        'minDetectionConfidence': 0.5,
        'minTrackingConfidence': 0.5,
      }.jsify()! as JSObject,
    );
    mesh.onResults(((JSObject results) {
      _onMeshResults(results);
    }).toJS);
    return mesh as JSObject;
  }

  Future<void> _pump(web.HTMLVideoElement video) async {
    final mesh = _faceMesh;
    if (mesh == null) return;
    while (_tracking) {
      final started = DateTime.now();
      try {
        final input = JSObject()..setProperty('image'.toJS, video);
        await (mesh as _FaceMesh).send(input).toDart;
      } catch (_) {
        _droppedFrames++;
      }
      final elapsed = DateTime.now().difference(started).inMicroseconds / 1000;
      _avgMs = _avgMs == 0 ? elapsed : (_avgMs * 0.9 + elapsed * 0.1);
      if (elapsed > _maxMs) _maxMs = elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 33));
    }
  }

  void _onMeshResults(JSObject results) {
    if (!_tracking) return;
    final faces = results.getProperty('multiFaceLandmarks'.toJS);
    if (faces.isUndefinedOrNull) {
      _droppedFrames++;
      return;
    }
    final list = faces as JSArray<JSObject>;
    if (list.length == 0) {
      _gazeController.add(GazeResult.noFace());
      return;
    }
    final landmarks = list[0];
    final result = _estimate(landmarks);
    if (result == null) {
      _droppedFrames++;
      return;
    }
    _totalFrames++;
    _fpsWindowFrames++;
    final now = DateTime.now();
    final windowMs = now.difference(_fpsWindowStart).inMilliseconds;
    if (windowMs >= 1000) {
      _fps = _fpsWindowFrames * 1000 / windowMs;
      _fpsWindowFrames = 0;
      _fpsWindowStart = now;
    }
    _latest = result;
    _gazeController.add(result);
  }

  GazeResult? _estimate(JSObject landmarks) {
    Offset? at(int i) {
      final point = landmarks.getProperty(i.toJS);
      if (point.isUndefinedOrNull) return null;
      final p = point as JSObject;
      final x = (p.getProperty('x'.toJS) as JSNumber?)?.toDartDouble;
      final y = (p.getProperty('y'.toJS) as JSNumber?)?.toDartDouble;
      if (x == null || y == null) return null;
      return Offset(x, y);
    }

    // MediaPipe iris (refineLandmarks): 468 left, 473 right.
    final leftIris = at(468);
    final rightIris = at(473);
    final leftInner = at(133);
    final leftOuter = at(33);
    final rightInner = at(362);
    final rightOuter = at(263);
    final leftTop = at(159);
    final leftBottom = at(145);
    final nose = at(1);
    final leftCheek = at(234);
    final rightCheek = at(454);
    if (leftInner == null ||
        leftOuter == null ||
        rightInner == null ||
        rightOuter == null ||
        nose == null) {
      return null;
    }

    final irisL = leftIris ??
        Offset(
          (leftInner.dx + leftOuter.dx) / 2,
          (leftInner.dy + leftOuter.dy) / 2,
        );
    final irisR = rightIris ??
        Offset(
          (rightInner.dx + rightOuter.dx) / 2,
          (rightInner.dy + rightOuter.dy) / 2,
        );

    double ratio(Offset iris, Offset inner, Offset outer) {
      final span = outer.dx - inner.dx;
      if (span.abs() < 1e-5) return 0.5;
      return ((iris.dx - inner.dx) / span).clamp(0.0, 1.0);
    }

    final rx = (ratio(irisL, leftInner, leftOuter) +
            ratio(irisR, rightInner, rightOuter)) /
        2;
    final leftSpanY = (leftBottom?.dy ?? irisL.dy) - (leftTop?.dy ?? irisL.dy);
    final ry = leftSpanY.abs() < 1e-5
        ? 0.5
        : ((irisL.dy - (leftTop?.dy ?? irisL.dy)) / leftSpanY).clamp(0.0, 1.0);

    final faceCx =
        ((leftCheek ?? leftOuter).dx + (rightCheek ?? rightOuter).dx) / 2;
    final yaw = ((nose.dx - faceCx) * 90).clamp(-45.0, 45.0);
    final pitch = ((nose.dy - irisL.dy) * 90).clamp(-45.0, 45.0);

    final width = web.window.innerWidth.toDouble();
    final height = web.window.innerHeight.toDouble();
    // Selfie camera is mirrored: look right → iris moves left in the frame.
    var x = width * (1 - rx);
    var y = height * ry;
    x += yaw / 45 * width * 0.15;
    y += pitch / 45 * height * 0.15;

    if (_calibration.length >= 3) {
      x = _mapCalibrated(x, true);
      y = _mapCalibrated(y, false);
    }

    if (_hasSmooth) {
      x = _smoothX * 0.65 + x * 0.35;
      y = _smoothY * 0.65 + y * 0.35;
    }
    _smoothX = x;
    _smoothY = y;
    _hasSmooth = true;

    final ear = leftTop == null || leftBottom == null
        ? 0.3
        : (leftBottom.dy - leftTop.dy).abs() /
            (leftOuter.dx - leftInner.dx).abs().clamp(1e-5, 10);
    final blinking = ear < 0.18;

    return GazeResult(
      gazePoint: Offset(x.clamp(0, width), y.clamp(0, height)),
      confidence: blinking ? 0.35 : 0.75,
      isBlinking: blinking,
      headPose: HeadPose(pitch: pitch, yaw: yaw, roll: 0),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      statusText: blinking ? 'Blink detected' : 'Tracking',
    );
  }

  double _mapCalibrated(double value, bool isX) {
    var sumW = 0.0;
    var sum = 0.0;
    for (final p in _calibration) {
      final expected = isX ? p.expected.dx : p.expected.dy;
      final actual = isX ? p.actual.dx : p.actual.dy;
      final d = (actual - value).abs() + 1;
      final w = 1 / d;
      sumW += w;
      sum += expected * w;
    }
    return sumW == 0 ? value : sum / sumW;
  }
}

@JS('FaceMesh')
extension type _FaceMesh._(JSObject _) implements JSObject {
  external factory _FaceMesh(JSObject config);
  external void setOptions(JSObject options);
  external void onResults(JSFunction callback);
  external JSPromise<JSAny?> send(JSObject input);
}
