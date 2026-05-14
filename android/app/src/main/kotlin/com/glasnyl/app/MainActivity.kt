package com.glasnyl.app

import android.media.audiofx.Visualizer
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
        // ✅ Flutter가 시스템 바 영역까지 직접 그리도록 위임 (edge-to-edge)
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // ✅ [Android 15 대응] LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES는 API 35에서 deprecated됨
        // → LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS 로 교체 (API 31+)
        // → Android P ~ R 구형 기기는 기존 SHORT_EDGES 유지
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            window.attributes.layoutInDisplayCutoutMode =
                android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        super.onCreate(savedInstanceState)
    }

    private val METHOD_CHANNEL = "com.glasnyl.app/media_control"
    private val EVENT_CHANNEL = "com.glasnyl.app/media_status"
    private val PIP_CHANNEL = "com.glasnyl.app/pip_status"
    private val VOLUME_CHANNEL = "com.glasnyl.app/volume_events"
    private val FFT_CHANNEL = "com.glasnyl.app/fft_data"

    private var visualizer: Visualizer? = null
    private var fftEventSink: EventChannel.EventSink? = null
    // 🚀 앨범아트를 폴링 데이터에서 분리 — SmartClip IPC 버퍼 오버플로우 방지
    private var cachedAlbumArt: ByteArray = ByteArray(0)
    private var cachedAlbumArtTitle: String = ""
    private var eventSink: EventChannel.EventSink? = null
    private var volumeEventSink: EventChannel.EventSink? = null
    private var volumeObserver: android.database.ContentObserver? = null
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
                    val keyCode = call.argument<Int>("keyCode") ?: 0
                    val mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
                    val componentName = ComponentName(this, "com.notification_listener_service.NotificationListenerServiceImpl")
                    
                    // 🚀 [수정] 버튼 누를 때마다 현재 "진짜로 재생 중인" 세션을 새로 찾습니다.
                    val controllers = mediaSessionManager.getActiveSessions(componentName)
                    
                    if (controllers.isNotEmpty()) {
                        val controller = controllers.find { it.playbackState?.state == PlaybackState.STATE_PLAYING } ?: controllers[0]
                        
                        // 🚀 [핵심] 오디오 매니저가 아니라 컨트롤러에게 직접 명령을 내립니다.
                        when (keyCode) {
                            87 -> controller.transportControls.skipToNext()      // 다음 곡
                            88 -> controller.transportControls.skipToPrevious()  // 이전 곡
                            85 -> { // 재생/일시정지 토글
                                if (controller.playbackState?.state == PlaybackState.STATE_PLAYING) {
                                    controller.transportControls.pause()
                                } else {
                                    controller.transportControls.play()
                                }
                            }
                            else -> {
                                // 기타 키는 기존 방식 유지
                                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                                audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
                                audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
                            }
                        }
                        
                        // 🚀 명령 전송 후 정보를 즉시 갱신하도록 유도
                        handler.postDelayed({ pushStatusUpdate() }, 300)
                        result.success(true)
                    } else {
                        result.error("NO_SESSION", "Active session not found", null)
                    }
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
                "getAlbumArt" -> {
                    // 🚀 앨범아트는 폴링과 분리해 Flutter가 필요할 때만 요청
                    result.success(cachedAlbumArt)
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
                "setVolume" -> {
                    val volume = (call.argument<Double>("volume") ?: 0.8).coerceIn(0.0, 1.0)
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val targetVol = (volume * maxVol).toInt().coerceIn(0, maxVol)
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, 0)
                    result.success(null)
                }
                "getVolume" -> {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val curVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    result.success(curVol.toDouble() / maxVol.toDouble())
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

        // 볼륨 버튼 이벤트 채널 — ContentObserver로 시스템 볼륨 변화 감지
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeEventSink = events
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    // 앱 시작 시 현재 볼륨 즉시 전송
                    val curVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    events?.success(curVol.toDouble() / maxVol.toDouble())
                    // 이후 볼륨 변화 감지
                    volumeObserver = object : android.database.ContentObserver(Handler(Looper.getMainLooper())) {
                        override fun onChange(selfChange: Boolean) {
                            val cur = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                            handler.post { volumeEventSink?.success(cur.toDouble() / maxVol.toDouble()) }
                        }
                    }
                    contentResolver.registerContentObserver(
                        android.provider.Settings.System.CONTENT_URI,
                        true,
                        volumeObserver!!
                    )
                }
                override fun onCancel(arguments: Any?) {
                    volumeObserver?.let { contentResolver.unregisterContentObserver(it) }
                    volumeObserver = null
                    volumeEventSink = null
                }
            }
        )

        // FFT Visualizer 채널 — 전체 오디오 출력 믹스 시각화
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FFT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    fftEventSink = events
                    startVisualizer()
                }
                override fun onCancel(arguments: Any?) {
                    fftEventSink = null
                    stopVisualizer()
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
            // 🚀 내 앱(package)에게만 신호를 보내도록 주소를 찍는 겁니다.
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
    // ── FFT Visualizer 시작
    private fun startVisualizer() {
        try {
            stopVisualizer()
            val v = Visualizer(0) // 0 = 전체 출력 믹스 (외부 앱 포함)
            // captureSize 1024 → FFT 빈 512개 확보, 고주파 해상도 대폭 향상
            v.captureSize = Visualizer.getCaptureSizeRange()[1].coerceAtMost(1024)
            val NUM_BANDS = 32
            v.setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                override fun onFftDataCapture(vis: Visualizer, fft: ByteArray, samplingRate: Int) {
                    if (fftEventSink == null) return
                    // fft[0] = DC, fft[1] = Nyquist → 2부터 실제 스펙트럼
                    // 각 빈은 실수/허수 쌍 → magnitude = sqrt(re²+im²)
                    // fft.size = captureSize, 유효 빈 수 = captureSize/2 - 1
                    val numBins = fft.size / 2  // 실질적 주파수 빈 수
                    val bands = FloatArray(NUM_BANDS)

                    // 로그 스케일 경계: 인간 청각에 맞게 저음에 빈 몰아주기
                    // 20Hz~20kHz 를 NUM_BANDS 구간으로 로그 분할
                    val freqPerBin = samplingRate.toFloat() / fft.size
                    val minFreq = 20f
                    val maxFreq = (samplingRate / 2).toFloat()

                    for (band in 0 until NUM_BANDS) {
                        // 각 밴드의 주파수 경계 (로그 스케일)
                        val fLow  = minFreq * Math.pow((maxFreq / minFreq).toDouble(), band.toDouble() / NUM_BANDS).toFloat()
                        val fHigh = minFreq * Math.pow((maxFreq / minFreq).toDouble(), (band + 1).toDouble() / NUM_BANDS).toFloat()

                        val binLow  = (fLow  / freqPerBin).toInt().coerceIn(1, numBins - 1)
                        val binHigh = (fHigh / freqPerBin).toInt().coerceIn(binLow + 1, numBins)

                        var sumSq = 0.0
                        var count = 0
                        for (bin in binLow until binHigh) {
                            val re = fft[bin * 2].toInt().toDouble()
                            val im = if (bin * 2 + 1 < fft.size) fft[bin * 2 + 1].toInt().toDouble() else 0.0
                            sumSq += re * re + im * im
                            count++
                        }
                        val rms = if (count > 0) Math.sqrt(sumSq / count) / 128.0 else 0.0

                        // 고주파 대역 적극 boost: band 0=1.0x, band 31=6.0x
                        val t = band.toDouble() / (NUM_BANDS - 1)
                        val boost = 1.0 + t * t * 5.0  // 제곱 커브로 고주파일수록 급격히 증폭
                        bands[band] = (rms * boost).toFloat().coerceIn(0f, 1f)
                    }
                    handler.post { fftEventSink?.success(bands.toList()) }
                }
                override fun onWaveFormDataCapture(vis: Visualizer, waveform: ByteArray, samplingRate: Int) {}
            },
            20000, // 초당 20회 캡처 (20000 mHz)
            false, true) // waveform=false, fft=true
            v.enabled = true
            visualizer = v
        } catch (e: Exception) {
            // Visualizer 권한 없거나 기기 미지원 시 조용히 실패
            visualizer = null
        }
    }

    private fun stopVisualizer() {
        try {
            visualizer?.enabled = false
            visualizer?.release()
        } catch (e: Exception) {}
        visualizer = null
    }

    override fun onStart() {
        super.onStart()
        if (fftEventSink != null) startVisualizer()
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
        stopVisualizer()
        try { unregisterReceiver(pipReceiver) } catch (e: Exception) {}
        volumeObserver?.let { contentResolver.unregisterContentObserver(it) }
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
                // 🚀 [핵심 수정] 현재 실제로 재생 중인(Playing) 세션을 우선적으로 찾습니다.
                val controller = controllers.find { it.playbackState?.state == PlaybackState.STATE_PLAYING } 
                                 ?: controllers[0]
                
                // 세션 토큰이 바뀌었을 경우에만 콜백을 새로 등록합니다.
                if (activeController?.sessionToken != controller.sessionToken) {
                    activeController?.unregisterCallback(mediaCallback)
                    activeController = controller
                    activeController?.registerCallback(mediaCallback)
                }

                val playbackState = controller.playbackState
                val metadata = controller.metadata

                val currentTitle = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "Unknown"

                // 🚀 앨범아트는 제목 변경 시에만 캐시 갱신 — 폴링 데이터에 포함 안 함
                if (currentTitle != cachedAlbumArtTitle) {
                    val bitmap = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                               ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
                    val newArt = bitmap?.let {
                        val scaledBitmap = Bitmap.createScaledBitmap(it, 300, 300, true)
                        val stream = ByteArrayOutputStream()
                        scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
                        stream.toByteArray()
                    }
                    if (newArt != null) {
                        cachedAlbumArt = newArt
                        cachedAlbumArtTitle = currentTitle
                    } else {
                        cachedAlbumArt = ByteArray(0)
                    }
                }

                // Flutter로 보낼 데이터 맵 (앨범아트 제외 — getAlbumArt 메서드로 별도 요청)
                mutableMapOf<String, Any>(
                    "position" to (playbackState?.position ?: 0L),
                    "duration" to (metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L),
                    "isPlaying" to (playbackState?.state == PlaybackState.STATE_PLAYING),
                    "title" to currentTitle,
                    "artist" to (metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: "Unknown Artist")
                )
            } else {
                // 활성화된 세션이 없을 때 기본값
                mutableMapOf<String, Any>(
                    "position" to 0L,
                    "duration" to 0L,
                    "isPlaying" to false,
                    "title" to "Ready to Play",
                    "artist" to "GLASNYL",
                )
            }
        } catch (e: Exception) { 
            null 
        }
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