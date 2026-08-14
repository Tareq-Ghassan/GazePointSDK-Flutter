/// Options for [GazeTracker.initialize].
///
/// Metrics always stream while tracking. Preview is opt-in: leave
/// [previewEnabled] false if the app only needs gaze numbers, or set it true
/// and place a [GazePreview] widget to show the live camera.
class GazeTrackerOptions {
  /// Bind a live camera preview that [GazePreview] can display.
  ///
  /// When false (the default), the SDK still runs face detection and sends
  /// [GazeResult]s — it just does not attach a preview surface.
  final bool previewEnabled;

  /// Draw a white rectangle around every detected face on the native preview.
  ///
  /// Ignored when [previewEnabled] is false. Implemented by the native SDKs.
  final bool showFaceBoxes;

  /// Creates tracker options.
  const GazeTrackerOptions({
    this.previewEnabled = false,
    this.showFaceBoxes = true,
  });

  /// Copy with selected fields replaced.
  GazeTrackerOptions copyWith({
    bool? previewEnabled,
    bool? showFaceBoxes,
  }) {
    return GazeTrackerOptions(
      previewEnabled: previewEnabled ?? this.previewEnabled,
      showFaceBoxes: showFaceBoxes ?? this.showFaceBoxes,
    );
  }

  /// Platform-channel payload.
  Map<String, dynamic> toJson() {
    return {
      'previewEnabled': previewEnabled,
      'showFaceBoxes': showFaceBoxes,
    };
  }
}
