package com.streammagnet.stream_magnet

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.File

class MainActivity : FlutterActivity() {
    private val ENGINE_CHANNEL = "com.streammagnet/torrent_engine"
    private val EVENTS_CHANNEL = "com.streammagnet/torrent_events"
    private val INTENT_CHANNEL = "com.streammagnet/app_intent"

    private var eventSink: EventChannel.EventSink? = null
    private var pendingIntentUri: String? = null
    private val mainScope = CoroutineScope(Dispatchers.Main + Job())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val data: Uri? = intent.data

        if (Intent.ACTION_VIEW == action && data != null) {
            val uriString = data.toString()
            pendingIntentUri = uriString
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Torrent Engine Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ENGINE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    val cachePath = call.argument<String>("cachePath") ?: cacheDir.absolutePath
                    result.success(true)
                }
                "startForegroundService" -> {
                    val title = call.argument<String>("title") ?: "Streaming Video"
                    TorrentStreamingService.startService(this, title)
                    result.success(true)
                }
                "updateForegroundService" -> {
                    val title = call.argument<String>("title") ?: "Streaming Video"
                    val speed = call.argument<String>("speed") ?: "0 KB/s"
                    val peers = call.argument<Int>("peers") ?: 0
                    TorrentStreamingService.updateService(this, title, speed, peers)
                    result.success(true)
                }
                "stopForegroundService" -> {
                    TorrentStreamingService.stopService(this)
                    result.success(true)
                }
                "pause" -> {
                    result.success(true)
                }
                "resume" -> {
                    result.success(true)
                }
                "stop" -> {
                    TorrentStreamingService.stopService(this)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Torrent Events Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        // App Intent Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialUri" -> {
                    val uri = pendingIntentUri
                    pendingIntentUri = null
                    result.success(uri)
                }
                else -> result.notImplemented()
            }
        }
    }
}
