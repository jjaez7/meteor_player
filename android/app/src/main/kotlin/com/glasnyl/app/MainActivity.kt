package com.glasnyl.app

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
import android.content.res.Configuration
import android.app.PendingIntent
import android.app.RemoteAction
import android.app.PictureInPictureParams
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.graphics.drawable.Icon
import android.os.Build
import androidx.core.view.WindowCompat
import android.os.Bundle

class MainActivity: AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode = 
                android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        super.onCreate(savedInstanceState)
    }
    private val METHOD_CHANNEL = "com.glasnyl.app/media_control"
    private val EVENT_CHANNEL = "com.glasnyl.app/media_status"
    private val PIP_CHANNEL = "com.glasnyl.app/pip_status"
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private var lastTitle: String? = null
    
    private var activeController: MediaController? = null
    private var pipMethodChannel: MethodChannel? = null

    // 🚀 [추가] PiP 시스템 버튼 클릭 수신 리시버
    private val pipReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.action?.let { action ->
                // 버튼 클릭 시 Flutter의 PIP_CHANNEL을 통해 이벤트 전송
                pipMethodChannel?.invokeMethod("onPipAction", action)
            }
        }
    }

    // 🚀 PiP 변경 감지 오버라이드
    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipMethodChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    private val mediaCallback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) {
            pushStatusUpdate()
            // 🚀 재생 상태 변경 시 PIP 버튼 아이콘도 갱신
            updatePipParams()
        }
        override fun onMetadataChanged(metadata: MediaMetadata?) {
            pushStatusUpdate()
            updatePipParams()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(android.util.Rational(23, 10))
                            .setActions(createPipActions()) // 🚀 버튼 세팅
                            .build()
                        enterPictureInPictureMode(params)
                        result.success(true)
                    } else {
                        result.error("VERSION_LOW", "PiP requires Android Oreo or higher", null)
                    }
                }
                "requestMetadataRefresh" -> {
                    // 1. 강제로 현재 상태를 읽어옴
                    val status = getMediaStatus()
                    if (status != null) {
                        // 2. 이벤트 채널을 통해 Flutter로 즉시 전송
                        eventSink?.success(status)
                        result.success(true)
                    } else {
                        result.error("REFRESH_FAILED", "No active session to refresh", null)
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

    // 🚀 [추가] PIP 버튼 생성
    private fun createPipActions(): List<RemoteAction> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return emptyList()

        val isPlaying = activeController?.playbackState?.state == PlaybackState.STATE_PLAYING

        return listOf(
            createAction(android.R.drawable.ic_media_previous, "Previous", "PREV", 1),
            createAction(if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play, 
                         if (isPlaying) "Pause" else "Play", "TOGGLE", 2),
            createAction(android.R.drawable.ic_media_next, "Next", "NEXT", 3)
        )
    }

private fun createAction(iconRes: Int, title: String, action: String, requestCode: Int): RemoteAction {
    val intent = Intent(action).apply {
        // 🚀 이 줄을 추가합니다. 내 앱(package)에게만 신호를 보내도록 주소를 찍는 겁니다.
        `package` = packageName 
    }
    
    val pendingIntent = PendingIntent.getBroadcast(
        this, 
        requestCode, 
        intent, 
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )
    return RemoteAction(Icon.createWithResource(this, iconRes), title, title, pendingIntent)
}

    private fun updatePipParams() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isInPictureInPictureMode) {
            setPictureInPictureParams(PictureInPictureParams.Builder()
                .setActions(createPipActions())
                .build())
        }
    }

    // 🚀 [추가] 앱 생명주기에 따른 리시버 등록/해제
    override fun onStart() {
        super.onStart()
        val filter = IntentFilter().apply {
            addAction("PREV")
            addAction("TOGGLE")
            addAction("NEXT")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(pipReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(pipReceiver) } catch (e: Exception) {}
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
                    val scaledBitmap = Bitmap.createScaledBitmap(it, 300, 300, true)
                    val stream = ByteArrayOutputStream()
                    scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
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
            } else {
                mutableMapOf<String, Any>(
                    "position" to 0L,
                    "duration" to 0L,
                    "isPlaying" to false, // 엔진을 멈추게 함
                    "title" to "Ready to Play",
                    "artist" to "GLASNYL",
                    "albumArt" to ByteArray(0)
                )
            }
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