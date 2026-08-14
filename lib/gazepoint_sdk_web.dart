import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui';
import 'dart:ui_web' as ui_web;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/gaze_preview.dart';
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
    final plugin = GazepointSdkWeb();
    GazepointSdkPlatform.instance = plugin;
    ui_web.platformViewRegistry.registerViewFactory(
      GazePreview.viewType,
      (int viewId) => plugin._previewHost,
    );
  }

  GazepointSdkWeb() {
    _video = web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true');
    _video.style
      ..setProperty('width', '100%')
      ..setProperty('height', '100%')
      ..setProperty('object-fit', 'cover')
      ..setProperty('transform', 'scaleX(-1)');

    _overlay = web.HTMLCanvasElement();
    _overlay.style
      ..setProperty('position', 'absolute')
      ..setProperty('inset', '0')
      ..setProperty('width', '100%')
      ..setProperty('height', '100%')
      ..setProperty('pointer-events', 'none');

    _previewHost = web.HTMLDivElement();
    _previewHost.style
      ..setProperty('width', '100%')
      ..setProperty('height', '100%')
      ..setProperty('position', 'relative')
      ..setProperty('overflow', 'hidden')
      ..setProperty('background', '#000');
    _previewHost.append(_video);
    _previewHost.append(_overlay);
  }

  static const _faceMeshCdn =
      'https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh@0.4.1633559619';

  static const _faceOval = <int>[
    10,
    338,
    297,
    332,
    284,
    251,
    389,
    356,
    454,
    323,
    361,
    288,
    397,
    365,
    379,
    378,
    400,
    377,
    152,
    148,
    176,
    149,
    150,
    136,
    172,
    58,
    132,
    93,
    234,
    127,
    162,
    21,
    54,
    103,
    67,
    109,
  ];

  final _gazeController = StreamController<GazeResult>.broadcast();
  late final web.HTMLDivElement _previewHost;
  late final web.HTMLVideoElement _video;
  late final web.HTMLCanvasElement _overlay;
  web.MediaStream? _stream;
  JSObject? _faceMesh;
  bool _initialized = false;
  bool _tracking = false;
  bool _scriptsLoaded = false;
  bool _previewEnabled = false;
  bool _showFaceBoxes = true;
  bool _usingFront = true;
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
    _previewEnabled = options.previewEnabled;
    _showFaceBoxes = options.showFaceBoxes;
    _initialized = true;
  }

  @override
  Future<void> setPreviewEnabled(bool enabled) async {
    _previewEnabled = enabled;
    if (!enabled) {
      _clearBoxes();
    }
  }

  @override
  Future<void> switchCamera() async {
    _usingFront = !_usingFront;
    _video.style.setProperty(
      'transform',
      _usingFront ? 'scaleX(-1)' : 'none',
    );
    if (!_tracking) return;
    _stopTracks();
    try {
      _stream = await _openCamera();
    } catch (_) {
      _usingFront = !_usingFront;
      _video.style.setProperty(
        'transform',
        _usingFront ? 'scaleX(-1)' : 'none',
      );
      _stream = await _openCamera();
    }
    _video.srcObject = _stream;
    await _video.play().toDart;
  }

  @override
  Future<void> startTracking() async {
    if (!_initialized) {
      throw StateError('Call initialize() first');
    }
    _stream ??= await _openCamera();
    _video.srcObject = _stream;
    await _video.play().toDart;
    _faceMesh ??= _createFaceMesh();
    _tracking = true;
    _pump();
  }

  @override
  Future<void> stopTracking() async {
    _tracking = false;
    _video.pause();
    _stopTracks();
    _clearBoxes();
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
      video: {
        'facingMode': _usingFront ? 'user' : 'environment',
        'width': 1280,
        'height': 720,
      }.jsify()!,
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
    _video.srcObject = null;
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
        'maxNumFaces': 4,
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

  Future<void> _pump() async {
    final mesh = _faceMesh;
    if (mesh == null) return;
    while (_tracking) {
      final started = DateTime.now();
      try {
        final input = JSObject()..setProperty('image'.toJS, _video);
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
    final count = list.length;

    if (_previewEnabled && _showFaceBoxes) {
      _drawBoxes(list);
    } else {
      _clearBoxes();
    }

    if (count != 1) {
      _hasSmooth = false;
      final frame = GazeResult.noFace(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        faceCount: count,
        statusText: count > 1 ? 'Multiple faces detected' : 'No face detected',
      );
      _latest = frame;
      _gazeController.add(frame);
      return;
    }

    final result = _estimate(list[0]);
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

  void _drawBoxes(JSArray<JSObject> faces) {
    final ctx = _overlay.context2D;
    final viewW = _previewHost.clientWidth.toDouble();
    final viewH = _previewHost.clientHeight.toDouble();
    final vw = _video.videoWidth.toDouble();
    final vh = _video.videoHeight.toDouble();
    if (viewW < 1 || viewH < 1 || vw < 1 || vh < 1) return;

    final dpr = web.window.devicePixelRatio;
    final pixelW = (viewW * dpr).round();
    final pixelH = (viewH * dpr).round();
    if (_overlay.width != pixelW || _overlay.height != pixelH) {
      _overlay.width = pixelW;
      _overlay.height = pixelH;
    }
    ctx.clearRect(0, 0, _overlay.width, _overlay.height);

    final scale = viewW / vw > viewH / vh ? viewW / vw : viewH / vh;
    final drawnW = vw * scale;
    final drawnH = vh * scale;
    final ox = (viewW - drawnW) / 2;
    final oy = (viewH - drawnH) / 2;

    ctx.strokeStyle = '#ffffff'.toJS;
    ctx.lineWidth = 3 * dpr;
    for (var i = 0; i < faces.length; i++) {
      final box = _boxFromLandmarks(faces[i]);
      if (box == null) continue;
      var left = box.$1 * drawnW + ox;
      var top = box.$2 * drawnH + oy;
      final width = box.$3 * drawnW;
      final height = box.$4 * drawnH;
      if (_usingFront) {
        left = viewW - left - width;
      }
      final insetX = width * 0.08;
      final insetY = height * 0.06;
      ctx.strokeRect(
        (left + insetX) * dpr,
        (top + insetY) * dpr,
        (width - insetX * 2).clamp(0, width) * dpr,
        (height - insetY * 2).clamp(0, height) * dpr,
      );
    }
  }

  (double, double, double, double)? _boxFromLandmarks(JSObject landmarks) {
    var minX = 1.0;
    var minY = 1.0;
    var maxX = 0.0;
    var maxY = 0.0;
    var used = 0;
    for (final i in _faceOval) {
      final p = _at(landmarks, i);
      if (p == null) continue;
      used++;
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    if (used < 2) return null;
    return (minX, minY, (maxX - minX).clamp(0, 1), (maxY - minY).clamp(0, 1));
  }

  void _clearBoxes() {
    _overlay.context2D.clearRect(0, 0, _overlay.width, _overlay.height);
  }

  Offset? _at(JSObject landmarks, int i) {
    final point = landmarks.getProperty(i.toJS);
    if (point.isUndefinedOrNull) return null;
    final p = point as JSObject;
    final x = (p.getProperty('x'.toJS) as JSNumber?)?.toDartDouble;
    final y = (p.getProperty('y'.toJS) as JSNumber?)?.toDartDouble;
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  GazeResult? _estimate(JSObject landmarks) {
    final leftInner = _at(landmarks, 133);
    final leftOuter = _at(landmarks, 33);
    final rightInner = _at(landmarks, 362);
    final rightOuter = _at(landmarks, 263);
    final leftTop = _at(landmarks, 159);
    final leftBottom = _at(landmarks, 145);
    final rightTop = _at(landmarks, 386);
    final rightBottom = _at(landmarks, 374);
    final nose = _at(landmarks, 1);
    final leftCheek = _at(landmarks, 234);
    final rightCheek = _at(landmarks, 454);
    if (leftInner == null ||
        leftOuter == null ||
        rightInner == null ||
        rightOuter == null ||
        nose == null) {
      return null;
    }

    final irisL = _at(landmarks, 468) ??
        Offset(
          (leftInner.dx + leftOuter.dx) / 2,
          (leftInner.dy + leftOuter.dy) / 2,
        );
    final irisR = _at(landmarks, 473) ??
        Offset(
          (rightInner.dx + rightOuter.dx) / 2,
          (rightInner.dy + rightOuter.dy) / 2,
        );

    double ratioX(Offset iris, Offset inner, Offset outer) {
      final span = outer.dx - inner.dx;
      if (span.abs() < 1e-5) return 0.5;
      return ((iris.dx - inner.dx) / span).clamp(0.0, 1.0);
    }

    double ratioY(Offset iris, Offset? top, Offset? bottom) {
      if (top == null || bottom == null) return 0.5;
      final span = bottom.dy - top.dy;
      if (span.abs() < 1e-5) return 0.5;
      return ((iris.dy - top.dy) / span).clamp(0.0, 1.0);
    }

    final rx = (ratioX(irisL, leftInner, leftOuter) +
            ratioX(irisR, rightInner, rightOuter)) /
        2;
    final ry = (ratioY(irisL, leftTop, leftBottom) +
            ratioY(irisR, rightTop, rightBottom)) /
        2;

    final faceCx =
        ((leftCheek ?? leftOuter).dx + (rightCheek ?? rightOuter).dx) / 2;
    final yaw = ((nose.dx - faceCx) * 90).clamp(-45.0, 45.0);
    final pitch = ((nose.dy - irisL.dy) * 90).clamp(-45.0, 45.0);

    final width = web.window.innerWidth.toDouble();
    final height = web.window.innerHeight.toDouble();
    final lookX = _usingFront ? 1 - rx : rx;
    final lookY = 0.5 + (ry - 0.5) * 0.35;
    var x = width * lookX;
    var y = height * lookY;
    x += ((_usingFront ? -yaw : yaw) / 45) * width * 0.12;
    y -= ((pitch - 8) / 45) * height * 0.12;

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
