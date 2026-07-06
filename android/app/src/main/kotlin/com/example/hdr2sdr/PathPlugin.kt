package com.example.hdr2sdr

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class PathPlugin(context: Context, engine: FlutterEngine) {
    companion object {
        private const val CHANNEL = "hdr2sdr/path"

        fun register(context: Context, engine: FlutterEngine) {
            PathPlugin(context, engine)
        }
    }

    private val dir: File

    init {
        // 使用 app 私有外部存储目录（无需任何权限）
        val baseDir = context.getExternalFilesDir(null)
            ?: context.filesDir
        dir = File(baseDir, "HDR2SDR_Output").also {
            if (!it.exists()) it.mkdirs()
        }

        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getOutputDirectory") {
                result.success(dir.absolutePath)
            } else {
                result.notImplemented()
            }
        }
    }
}

