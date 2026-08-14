import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'gaze_tracker.dart';

/// Hosts the native SDK camera preview ([GazePreviewView] on Android/iOS/macOS).
///
/// Face rectangles and multi-face handling are drawn by the native SDK.
/// Place this widget when [GazeTrackerOptions.previewEnabled] is true.
/// Metrics still arrive on [GazeTracker.gazeStream] if you never add it.
class GazePreview extends StatelessWidget {
  /// Platform view type registered by the Android / iOS / macOS plugins.
  static const viewType = 'gazepoint_sdk/preview';

  /// Tracker whose native session this preview displays.
  final GazeTracker tracker;

  /// Creates a host for the native SDK preview.
  const GazePreview({super.key, required this.tracker});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: tracker.previewEnabled,
      builder: (context, enabled, _) {
        if (!enabled) {
          return const ColoredBox(color: Colors.black);
        }
        return const _NativeCameraView();
      },
    );
  }
}

class _NativeCameraView extends StatelessWidget {
  const _NativeCameraView();

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const HtmlElementView(viewType: GazePreview.viewType);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const AndroidView(
          viewType: GazePreview.viewType,
          layoutDirection: TextDirection.ltr,
        );
      case TargetPlatform.iOS:
        return const UiKitView(
          viewType: GazePreview.viewType,
          layoutDirection: TextDirection.ltr,
        );
      case TargetPlatform.macOS:
        return const AppKitView(
          viewType: GazePreview.viewType,
          layoutDirection: TextDirection.ltr,
        );
      default:
        return const ColoredBox(color: Colors.black);
    }
  }
}
