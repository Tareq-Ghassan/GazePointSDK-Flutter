/// Head pose information (orientation in degrees)
class HeadPose {
  /// Pitch angle (nodding up and down)
  final double pitch;
  
  /// Yaw angle (turning left and right)
  final double yaw;
  
  /// Roll angle (tilting left and right)
  final double roll;

  /// Creates a [HeadPose] with the specified orientation angles.
  ///
  /// All angles are measured in degrees:
  /// - [pitch]: Nodding up (-) and down (+)
  /// - [yaw]: Turning left (-) and right (+)
  /// - [roll]: Tilting left (-) and right (+)
  const HeadPose({
    required this.pitch,
    required this.yaw,
    required this.roll,
  });

  /// Create from JSON
  factory HeadPose.fromJson(Map<String, dynamic> json) {
    return HeadPose(
      pitch: (json['pitch'] as num).toDouble(),
      yaw: (json['yaw'] as num).toDouble(),
      roll: (json['roll'] as num).toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'pitch': pitch,
      'yaw': yaw,
      'roll': roll,
    };
  }

  @override
  String toString() {
    return 'HeadPose(pitch: ${pitch.toStringAsFixed(1)}°, '
        'yaw: ${yaw.toStringAsFixed(1)}°, '
        'roll: ${roll.toStringAsFixed(1)}°)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HeadPose &&
        other.pitch == pitch &&
        other.yaw == yaw &&
        other.roll == roll;
  }

  @override
  int get hashCode => Object.hash(pitch, yaw, roll);
}
