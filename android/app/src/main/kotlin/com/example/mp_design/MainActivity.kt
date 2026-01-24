package com.example.mp_design

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
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
                // [추가] 앱 시작 시 현재 재생 중인 정보를 즉시 요청받는 핸들러
                "getCurrentStatus" -> {
                    val status = getMediaStatus()
                    if (status != null) {
                        result.success(status)
                    } else {
                        result.error("UNAVAILABLE", "No active media session", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startStatusUpdates()
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    // [핵심 로직 분리] 현재 재생 정보를 Map으로 반환하는 공용 함수
    private fun getMediaStatus(): Map<String, Any>? {
    return try {
        val mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
        val componentName = ComponentName(
            "com.example.mp_design",
            "com.notification_listener_service.NotificationListenerServiceImpl"
        )
        val controllers = mediaSessionManager.getActiveSessions(componentName)

        if (controllers.isNotEmpty()) {
            val controller = controllers[0]
            val playbackState = controller.playbackState
            val metadata = controller.metadata

            // [추가] 앨범 아트 가져오기 (Bitmap -> ByteArray)
            val bitmap = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART) 
                      ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
            
            val albumArtBytes = bitmap?.let {
            val scaledBitmap = Bitmap.createScaledBitmap(it, 400, 400, true)
            val stream = java.io.ByteArrayOutputStream()
            scaledBitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, stream) // JPEG 80%로 압축
            stream.toByteArray()
            }

            mutableMapOf<String, Any>(
                "position" to (playbackState?.position ?: 0L),
                "duration" to (metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L),
                "isPlaying" to (playbackState?.state == PlaybackState.STATE_PLAYING),
                "title" to (metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "Unknown"),
                "albumArt" to (albumArtBytes ?: ByteArray(0)) // 이미지가 없으면 빈 배열
            )
        } else null
    } catch (e: Exception) {
        null
    }
}

    private fun startStatusUpdates() {
        handler.post(object : Runnable {
            override fun run() {
                val data = getMediaStatus()
                if (data != null) {
                    eventSink?.success(data)
                }
                
                if (eventSink != null) {
                    handler.postDelayed(this, 1000)
                }
            }
        })
    }
}