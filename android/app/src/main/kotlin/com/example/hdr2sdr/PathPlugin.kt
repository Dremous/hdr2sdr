package com.example.hdr2sdr

import android.os.Environment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class PathPlugin(private val engine: FlutterEngine) {
    companion object {
        private const val CHANNEL = "hdr2sdr/path"

        fun register(engine: FlutterEngine) {
            PathPlugin(engine)
        }
    }

    init {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getOutputDirectory") {
                val dir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                ).absolutePath
                result.success(dir)
            } else {
                result.notImplemented()
            }
        }
    }
}
