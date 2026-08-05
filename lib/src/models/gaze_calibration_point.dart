import 'dart:ui';

/// A calibration sample pairing an expected screen point with the measured gaze point.
class GazeCalibrationPoint {
  /// Where the user was asked to look (screen coordinates).
  final Offset expected;

  /// Where the tracker reported the gaze at that moment (screen coordinates).
  final Offset actual;

  /// Creates a new calibration point with expected and actual gaze coordinates.
  ///
  /// The [expected] parameter represents where the user was asked to look,
  /// while [actual] represents where the tracker measured the gaze.
  const GazeCalibrationPoint({
    required this.expected,
    required this.actual,
  });

  /// Converts this calibration point to a JSON map.
  ///
  /// Returns a map with 'expected' and 'actual' keys, each containing
  /// x and y coordinates.
  Map<String, dynamic> toJson() {
    return {
      'expected': {'x': expected.dx, 'y': expected.dy},
      'actual': {'x': actual.dx, 'y': actual.dy},
    };
  }

  /// Creates a calibration point from a JSON map.
  ///
  /// The [json] parameter should contain 'expected' and 'actual' keys,
  /// each with x and y coordinate values.
  factory GazeCalibrationPoint.fromJson(Map<String, dynamic> json) {
    final expected = json['expected'] as Map<String, dynamic>;
    final actual = json['actual'] as Map<String, dynamic>;
    return GazeCalibrationPoint(
      expected: Offset(
        (expected['x'] as num).toDouble(),
        (expected['y'] as num).toDouble(),
      ),
      actual: Offset(
        (actual['x'] as num).toDouble(),
        (actual['y'] as num).toDouble(),
      ),
    );
  }
}
