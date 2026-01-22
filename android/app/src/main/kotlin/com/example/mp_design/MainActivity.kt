package com.example.mp_design

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.content.Context
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

    private var lastTitle: String? = null
    private var lastAlbumArt: ByteArray? = null

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
                "getCurrentStatus" -> {
                    val status = getMediaStatus()
                    if (status != null) result.success(status)
                    else result.error("UNAVAILABLE", "No active media session", null)
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
                    handler.removeCallbacksAndMessages(null)
                }
            }
        )
    }

    private fun getMediaStatus(): Map<String, Any>? {
        return try {
            val mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
            
            // 핵심 수정: null을 전달하여 '모든' 활성 세션을 가져옵니다. 
            // 컴포넌트를 지정하면 해당 앱의 세션만 가져오려 하기 때문에 다른 앱(유튜브 등)을 못 잡을 수 있습니다.
            val controllers = mediaSessionManager.getActiveSessions(null)

            if (controllers.isNotEmpty()) {
                // 현재 실제로 재생 중인(Active) 세션을 우선적으로 찾습니다.
                val controller = controllers.find { it.playbackState?.state == PlaybackState.STATE_PLAYING } 
                                 ?: controllers[0]
                
                val playbackState = controller.playbackState
                val metadata = controller.metadata

                val currentTitle = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "Unknown"
                
                // 앨범 아트 추출 로직 보강
                if (currentTitle != lastTitle) {
                    val bitmap = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART) 
                                 ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
                    
                    lastAlbumArt = bitmap?.let {
                        // 300x300 정도로 리사이징하여 전송 부하를 줄임
                        val scaledBitmap = Bitmap.createScaledBitmap(it, 300, 300, true)
                        val stream = ByteArrayOutputStream()
                        scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 75, stream)
                        stream.toByteArray()
                    }
                    lastTitle = currentTitle
                }

                mutableMapOf<String, Any>(
                    "position" to (playbackState?.position ?: 0L),
                    "duration" to (metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L),
                    "isPlaying" to (playbackState?.state == PlaybackState.STATE_PLAYING),
                    "title" to currentTitle,
                    "artist" to (metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: "Unknown Artist"),
                    "albumArt" to (lastAlbumArt ?: ByteArray(0))
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