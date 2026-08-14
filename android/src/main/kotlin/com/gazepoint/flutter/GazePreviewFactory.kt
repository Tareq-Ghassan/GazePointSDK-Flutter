package com.gazepoint.flutter

import android.content.Context
import android.view.View
import com.gazepoint.sdk.camera.GazePreviewView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Embeds the native SDK [GazePreviewView] (camera + face boxes).
 */
class GazePreviewFactory(
    private val plugin: GazepointSdkPlugin
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return GazePreviewPlatformView(context, plugin)
    }
}

class GazePreviewPlatformView(
    context: Context,
    private val plugin: GazepointSdkPlugin
) : PlatformView {
    private val previewView = GazePreviewView(context)

    init {
        plugin.attachPreview(previewView)
    }

    override fun getView(): View = previewView

    override fun dispose() {
        plugin.detachPreview(previewView)
    }
}
