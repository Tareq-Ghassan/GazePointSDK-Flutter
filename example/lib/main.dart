import 'package:flutter/material.dart';
import 'package:gazepoint_sdk/gazepoint_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GazePoint SDK Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
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
  final GazeTracker _gazeTracker = GazeTracker();
  Offset _gazePoint = Offset.zero;
  double _confidence = 0.0;
  bool _isBlinking = false;
  bool _isTracking = false;
  String _statusMessage = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initializeGazeTracking();
  }

  Future<void> _initializeGazeTracking() async {
    try {
      setState(() {
        _statusMessage = 'Initializing...';
      });

      await _gazeTracker.initialize();

      setState(() {
        _statusMessage = 'Initialized. Ready to start tracking.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Initialization failed: $e';
      });
    }
  }

  Future<void> _startTracking() async {
    try {
      await _gazeTracker.startTracking();

      _gazeTracker.gazeStream.listen((result) {
        setState(() {
          _gazePoint = result.gazePoint;
          _confidence = result.confidence;
          _isBlinking = result.isBlinking;
          _isTracking = true;
          _statusMessage = 'Tracking active';
        });
      });

      setState(() {
        _statusMessage = 'Tracking started';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Start tracking failed: $e';
      });
    }
  }

  Future<void> _stopTracking() async {
    try {
      await _gazeTracker.stopTracking();
      setState(() {
        _isTracking = false;
        _statusMessage = 'Tracking stopped';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Stop tracking failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _gazeTracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('GazePoint SDK Example'),
      ),
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Status: $_statusMessage',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (_isTracking) ...[
                      Text(
                        'Gaze Point: (${_gazePoint.dx.toStringAsFixed(0)}, ${_gazePoint.dy.toStringAsFixed(0)})',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Confidence: ${(_confidence * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Blinking: ${_isBlinking ? "Yes" : "No"}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isTracking ? null : _startTracking,
                    child: const Text('Start Tracking'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _isTracking ? _stopTracking : null,
                    child: const Text('Stop Tracking'),
                  ),
                ],
              ),
            ],
          ),
          if (_isTracking)
            Positioned(
              left: _gazePoint.dx - 15,
              top: _gazePoint.dy - 15,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
