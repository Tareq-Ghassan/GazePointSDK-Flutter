/// Converts a platform-channel map into `Map<String, dynamic>`.
///
/// iOS and macOS send `NSDictionary` as `Map<Object?, Object?>`. A shallow
/// `Map<String, dynamic>.from` leaves nested maps (for example `headPose`)
/// uncast, which then throws in `fromJson`.
Map<String, dynamic> jsonMap(Object? value) {
  if (value is! Map) {
    throw ArgumentError('Expected a Map, got ${value.runtimeType}');
  }
  return value.map((key, val) {
    final converted = val is Map ? jsonMap(val) : val;
    return MapEntry(key.toString(), converted);
  });
}
