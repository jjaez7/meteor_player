package com.example.mp_design

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import android.content.Context
import android.content.ComponentName 
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.graphics.Bitmap
import java.io.ByteArrayOutputStream
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity: AudioServiceActivity() {
    private val METHOD_CHANNEL = "com.meteor.player/media_control"
    private val EVENT_CHANNEL = "com.meteor.player/media_status"
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    
    private var activeController: MediaController? = null

    private val mediaCallback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) {
            pushStatusUpdate()
        }
        override fun onMetadataChanged(metadata: MediaMetadata?) {
            pushStatusUpdate()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendMediaKey" -> {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val keyCode = call.argument<Int>("keyCode") ?: 0
                    audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
                    audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
                    result.success(true)
                }
                "getCurrentStatus" -> {
                    val status = getMediaStatus()
                    if (status != null) result.success(status)
                    else result.error("UNAVAILABLE", "No session", null)
                }
                // 🚀 [추가] 특정 위치로 이동 (Seek) 로직
                "seek" -> {
                    val relativePos = call.argument<Double>("position") ?: 0.0
                    val mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
                    val componentName = ComponentName(this, "com.notification_listener_service.NotificationListenerServiceImpl")
                    val controllers = mediaSessionManager.getActiveSessions(componentName)

                    if (controllers.isNotEmpty()) {
                        val controller = controllers[0]
                        val duration = controller.metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
                        
                        if (duration > 0) {
                            val seekToMs = (duration * relativePos).toLong()
                            // 실제 미디어 세션에 이동 명령 전송
                            controller.transportControls.seekTo(seekToMs)
                            result.success(true)
                        } else {
                            result.error("NO_DURATION", "Cannot seek without duration", null)
                        }
                    } else {
                        result.error("NO_SESSION", "No active media session found", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startPolling()
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun pushStatusUpdate() {
        val data = getMediaStatus()
        if (data != null && eventSink != null) {
            handler.post { eventSink?.success(data) }
        }
    }

    private fun getMediaStatus(): Map<String, Any>? {
        return try {
            val mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
            val componentName = ComponentName(this, "com.notification_listener_service.NotificationListenerServiceImpl")
            val controllers = mediaSessionManager.getActiveSessions(componentName)

            if (controllers.isNotEmpty()) {
                val controller = controllers[0]
                
                if (activeController?.sessionToken != controller.sessionToken) {
                    activeController?.unregisterCallback(mediaCallback)
                    activeController = controller
                    activeController?.registerCallback(mediaCallback)
                }

                val playbackState = controller.playbackState
                val metadata = controller.metadata
                val bitmap = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART) 
                          ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
                
                val albumArtBytes = bitmap?.let {
                    val scaledBitmap = Bitmap.createScaledBitmap(it, 400, 400, true)
                    val stream = ByteArrayOutputStream()
                    scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 70, stream)
                    stream.toByteArray()
                }

                mutableMapOf<String, Any>(
                    "position" to (playbackState?.position ?: 0L),
                    "duration" to (metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L),
                    "isPlaying" to (playbackState?.state == PlaybackState.STATE_PLAYING),
                    "title" to (metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "Unknown"),
                    "artist" to (metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: "Unknown Artist"),
                    "albumArt" to (albumArtBytes ?: ByteArray(0))
                )
            } else null
        } catch (e: Exception) { null }
    }

    private fun startPolling() {
        handler.post(object : Runnable {
            override fun run() {
                if (eventSink != null) {
                    pushStatusUpdate()
                    handler.postDelayed(this, 1000)
                }
            }
        })
    }
}