package com.example.hdr2sdr

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private var backgroundEventSink: EventChannel.EventSink? = null

        fun sendBackgroundEvent(event: Map<String, Any>) {
            backgroundEventSink?.success(event)
        }
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        MethodChannel(engine.dartExecutor.binaryMessenger, "hdr2sdr/background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startConversion" -> {
                        val args = call.arguments as? Map<*, *>
                        val filePath = args?.get("filePath") as? String
                        val outputPath = args?.get("outputPath") as? String
                        val params = args?.get("params") as? Map<*, *>
                        if (filePath != null && outputPath != null) {
                            val intent = Intent(this, HdrConversionService::class.java).apply {
                                action = HdrConversionService.ACTION_START
                                putExtra(HdrConversionService.EXTRA_FILE_PATH, filePath)
                                putExtra(HdrConversionService.EXTRA_OUTPUT_PATH, outputPath)
                                if (params != null) {
                                    putExtra(HdrConversionService.EXTRA_ENCODER, (params["encoder"] as? Number)?.toInt() ?: 1)
                                    putExtra(HdrConversionService.EXTRA_CRF, (params["crf"] as? Number)?.toInt() ?: 23)
                                }
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "缺少必要参数", null)
                        }
                    }
                    "cancelConversion" -> {
                        val intent = Intent(this, HdrConversionService::class.java).apply {
                            action = HdrConversionService.ACTION_CANCEL
                        }
                        startService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(engine.dartExecutor.binaryMessenger, "hdr2sdr/background_event")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    backgroundEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    backgroundEventSink = null
                }
            })
    }
}
