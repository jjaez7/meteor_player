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
import android.content.res.Configuration // 🚀 추가: Configuration 임포트

class MainActivity: AudioServiceActivity() {
    private val METHOD_CHANNEL = "com.meteor.player/media_control"
    private val EVENT_CHANNEL = "com.meteor.player/media_status"
    private val PIP_CHANNEL = "com.meteor.player/pip_status" // 🚀 추가: PIP_CHANNEL 변수 정의
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private var lastTitle: String? = null
    
    private var activeController: MediaController? = null
    private var pipMethodChannel: MethodChannel? = null

    // 🚀 PiP 변경 감지 오버라이드
    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        // Flutter로 PiP 진입/이탈 여부를 즉시 전송
        pipMethodChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    private val mediaCallback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) {
            pushStatusUpdate()
        }
        override fun onMetadataChanged(metadata: MediaMetadata?) {
            pushStatusUpdate()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 🚀 PiP 채널 초기화
        pipMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)

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

                "enterPip" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        val aspectRatio = android.util.Rational(23, 10) 
        
                        val params = android.app.PictureInPictureParams.Builder()
                        .setAspectRatio(aspectRatio)
                        .build()
                        enterPictureInPictureMode(params)
                        result.success(true)
                    } else {
                        result.error("VERSION_LOW", "PiP requires Android Oreo or higher", null)
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
            val mediaSessionManager = getSystemService(Context.AUDIO_SERVICE).let { 
                getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager 
            }
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
                    val scaledBitmap = Bitmap.createScaledBitmap(it, 300, 300, true)
                    val stream = ByteArrayOutputStream()
                    scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
                    val bytes = stream.toByteArray()

                    if (bytes.size > 800 * 1024) {
                        val backupStream = ByteArrayOutputStream()
                        scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 40, backupStream)
                        backupStream.toByteArray()
                    } else {
                        bytes
                    }
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