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

  /// Creates a new gaze result with tracking data.
  ///
  /// - [gazePoint]: The calculated gaze point in screen coordinates
  /// - [confidence]: Confidence score from 0.0 to 1.0
  /// - [isBlinking]: Whether the user is currently blinking
  /// - [headPose]: Head pose information (pitch, yaw, roll)
  /// - [timestamp]: Timestamp in milliseconds since epoch
  const GazeResult({
    required this.gazePoint,
    required this.confidence,
    required this.isBlinking,
    required this.headPose,
    required this.timestamp,
  });

  /// Create from JSON (including platform-channel maps from iOS/macOS).
  factory GazeResult.fromJson(Map<dynamic, dynamic> json) {
    final map = jsonMap(json);
    return GazeResult(
      gazePoint: Offset(
        (map['gazePointX'] as num).toDouble(),
        (map['gazePointY'] as num).toDouble(),
      ),
      confidence: (map['confidence'] as num).toDouble(),
      isBlinking: map['isBlinking'] as bool,
      headPose: HeadPose.fromJson(jsonMap(map['headPose'])),
      timestamp: (map['timestamp'] as num).toInt(),
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
    };
  }

  @override
  String toString() {
    return 'GazeResult(gazePoint: $gazePoint, confidence: ${(confidence * 100).toStringAsFixed(0)}%, '
        'isBlinking: $isBlinking, headPose: $headPose)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GazeResult &&
        other.gazePoint == gazePoint &&
        other.confidence == confidence &&
        other.isBlinking == isBlinking &&
        other.headPose == headPose &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(gazePoint, confidence, isBlinking, headPose, timestamp);
  }
}
