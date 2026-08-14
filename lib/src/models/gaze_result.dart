import 'dart:ui';
import 'head_pose.dart';
import 'json_map.dart';

/// Result of gaze point calculation
class GazeResult {
  /// The calculated gaze point in screen coordinates
  final Offset gazePoint;

  /// Confidence score from 0.0 to 1.0
  final double confidence;

  /// Whether the user is blinking
  final bool isBlinking;

  /// Head pose information
  final HeadPose headPose;

  /// Timestamp of the result (milliseconds since epoch)
  final int timestamp;

  /// Whether at least one face is in frame.
  final bool faceDetected;

  /// Number of faces in this frame (0 if none).
  final int faceCount;

  /// Native SDK status line ("No face detected", "Multiple faces detected", …).
  final String statusText;

  /// Creates a new gaze result with tracking data.
  const GazeResult({
    required this.gazePoint,
    required this.confidence,
    required this.isBlinking,
    required this.headPose,
    required this.timestamp,
    this.faceDetected = true,
    this.faceCount = 1,
    this.statusText = 'Tracking',
  });

  /// Empty result used when the camera is running but no face is in frame.
  factory GazeResult.noFace({
    int timestamp = 0,
    int faceCount = 0,
    String statusText = 'No face detected',
  }) {
    return GazeResult(
      gazePoint: Offset.zero,
      confidence: 0,
      isBlinking: false,
      headPose: const HeadPose(pitch: 0, yaw: 0, roll: 0),
      timestamp: timestamp,
      faceDetected: false,
      faceCount: faceCount,
      statusText: statusText,
    );
  }

  /// True when more than one face is in frame.
  bool get hasMultipleFaces => faceCount > 1;

  /// Create from JSON (including platform-channel maps from iOS/macOS).
  factory GazeResult.fromJson(Map<dynamic, dynamic> json) {
    final map = jsonMap(json);
    final faceCount = (map['faceCount'] as num?)?.toInt() ?? 0;
    final faceDetected =
        map['faceDetected'] as bool? ?? map['gazePointX'] != null;
    final timestamp = (map['timestamp'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    final statusText = map['statusText'] as String? ??
        (faceCount > 1
            ? 'Multiple faces detected'
            : faceDetected
                ? 'Tracking'
                : 'No face detected');

    if (!faceDetected || map['gazePointX'] == null) {
      return GazeResult.noFace(
        timestamp: timestamp,
        faceCount: faceCount,
        statusText: statusText,
      );
    }

    return GazeResult(
      gazePoint: Offset(
        (map['gazePointX'] as num).toDouble(),
        (map['gazePointY'] as num).toDouble(),
      ),
      confidence: (map['confidence'] as num).toDouble(),
      isBlinking: map['isBlinking'] as bool? ?? false,
      headPose: map['headPose'] is Map
          ? HeadPose.fromJson(jsonMap(map['headPose']))
          : const HeadPose(pitch: 0, yaw: 0, roll: 0),
      timestamp: timestamp,
      faceDetected: true,
      faceCount: faceCount == 0 ? 1 : faceCount,
      statusText: statusText,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'gazePointX': gazePoint.dx,
      'gazePointY': gazePoint.dy,
      'confidence': confidence,
      'isBlinking': isBlinking,
      'headPose': headPose.toJson(),
      'timestamp': timestamp,
      'faceDetected': faceDetected,
      'faceCount': faceCount,
      'statusText': statusText,
    };
  }

  @override
  String toString() {
    return 'GazeResult($statusText, gazePoint: $gazePoint, '
        'confidence: ${(confidence * 100).toStringAsFixed(0)}%, '
        'faces: $faceCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GazeResult &&
        other.gazePoint == gazePoint &&
        other.confidence == confidence &&
        other.isBlinking == isBlinking &&
        other.headPose == headPose &&
        other.timestamp == timestamp &&
        other.faceDetected == faceDetected &&
        other.faceCount == faceCount &&
        other.statusText == statusText;
  }

  @override
  int get hashCode {
    return Object.hash(
      gazePoint,
      confidence,
      isBlinking,
      headPose,
      timestamp,
      faceDetected,
      faceCount,
      statusText,
    );
  }
}
