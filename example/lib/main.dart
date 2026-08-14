import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gazepoint_sdk/gazepoint_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GazePoint SDK Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GazeTrackingPage(),
    );
  }
}

class GazeTrackingPage extends StatefulWidget {
  const GazeTrackingPage({super.key});

  @override
  State<GazeTrackingPage> createState() => _GazeTrackingPageState();
}

class _GazeTrackingPageState extends State<GazeTrackingPage> {
  final GazeTracker _tracker = GazeTracker();
  StreamSubscription<GazeResult>? _subscription;
  GazeResult? _latest;
  bool _started = false;
  String _status = 'Starting camera…';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _tracker.initialize(
        options: const GazeTrackerOptions(
          previewEnabled: true,
          showFaceBoxes: true,
        ),
      );
      _subscription = _tracker.gazeStream.listen((result) {
        if (!mounted) return;
        setState(() {
          _latest = result;
          _status = result.statusText;
        });
      });
      final granted = await _tracker.requestCameraPermission();
      if (!granted) {
        setState(() {
          _status =
              'Camera permission denied. Enable Camera in app settings.';
        });
        return;
      }
      await _tracker.startTracking();
      if (!mounted) return;
      setState(() {
        _started = true;
        _status = 'Look at the screen — tracking…';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Failed: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _latest;
    final face = result?.faceDetected ?? false;
    final gaze = result?.gazePoint;
    final statusColor = face && !(result?.hasMultipleFaces ?? false)
        ? const Color(0xFF69F0AE)
        : const Color(0xFFFFD54F);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GazePreview(tracker: _tracker),
            if (face && gaze != null)
              Positioned(
                left: gaze.dx - 14,
                top: gaze.dy - 14,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 56,
              child: _StatusCard(
                status: _status,
                statusColor: statusColor,
                result: result,
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: TextButton(
                onPressed: _started ? _tracker.switchCamera : null,
                child: const Text(
                  'SWITCH CAMERA',
                  style: TextStyle(
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.statusColor,
    required this.result,
  });

  final String status;
  final Color statusColor;
  final GazeResult? result;

  @override
  Widget build(BuildContext context) {
    final face = result?.faceDetected ?? false;
    final gaze = result?.gazePoint;
    final pose = result?.headPose;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'GazePoint SDK Demo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(color: statusColor, fontSize: 14),
          ),
          const SizedBox(height: 4),
          if (face && gaze != null && pose != null) ...[
            Text(
              'Gaze: (${gaze.dx.toStringAsFixed(0)}, ${gaze.dy.toStringAsFixed(0)})  '
              'Confidence: ${((result?.confidence ?? 0) * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              'Head  pitch: ${pose.pitch.toStringAsFixed(1)}  '
              'yaw: ${pose.yaw.toStringAsFixed(1)}  '
              'roll: ${pose.roll.toStringAsFixed(1)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              result?.isBlinking == true ? 'Eyes: blinking' : 'Eyes: open',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ] else
            const Text(
              'Point the front camera at your face.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
