import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glasnyl/permission_guard.dart';
import 'player_screen.dart';
import 'onboarding_screen.dart';
import 'services/ad_service.dart';
import 'services/purchase_service.dart';

String appVersion="1.0.0";

late MyAudioHandler audioHandler;
final GlobalKey<PermissionGuardState> permissionGuardKey = GlobalKey<PermissionGuardState>();
void main() async {
  // 1. 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();



  // 2. 앱 설정 로드
  await AdService.initInstallTime();

  final packageInfo = await PackageInfo.fromPlatform();
  appVersion = packageInfo.version;

  // 3. 초기 로드 (SharedPreferences와 AudioService를 병렬로 초기화)
  final results = await Future.wait([
    SharedPreferences.getInstance(),
    AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.glasnyl.app.audio',
        androidNotificationChannelName: 'GLASNYL Control',
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: false,
      ),
    ),
  ]);

  final prefs = results[0] as SharedPreferences;
  audioHandler = results[1] as MyAudioHandler;

  final bool isFirstRun = prefs.getBool('isFirstRun') ?? true;

  // 4. UI 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(GlasnylPlayer(isFirstRun: isFirstRun));

  // 광고 초기화: runApp 이후 비동기 실행 (음악 채널 연결 차단 방지)
  unawaited(AdService.initAdmobWithDelay());
  // 결제 서비스 초기화 (purchaseStream 구독 시작)
}


class MyAudioHandler extends BaseAudioHandler {
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.glasnyl.app/media_control',
  );
  static const EventChannel _statusChannel = EventChannel(
    'com.glasnyl.app/media_status',
  );

  Stream<Duration> get position => playbackState.map((state) => state.updatePosition).distinct();
  
  // (옵션) 전체 길이 스트림도 있으면 편합니다.
  Stream<Duration> get duration => mediaItem.map((item) => item?.duration ?? Duration.zero).distinct();

  // 🚀 앱 복귀 시 Surface 재구성 동안 스트림 신호를 잠깐 차단하는 플래그
  bool _isSuppressed = false;

  /// player_screen의 didChangeAppLifecycleState(resumed)에서 호출.
  /// Android가 IME Input Channel을 재구성하는 800ms 동안 EventChannel 신호를 무시.
  void suppressForResume() {
    _isSuppressed = true;
    // 🚀 캡처/PiP 포함 Surface 재구성에 충분한 여유 시간 (1200ms)
    Future.delayed(const Duration(milliseconds: 1200), () {
      _isSuppressed = false;
    });
  }

  MyAudioHandler() {
    // 초기 상태 설정
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.play,
          MediaControl.pause,
          MediaControl.skipToNext,
          MediaControl.skipToPrevious,
        ],
        systemActions: {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        processingState: AudioProcessingState.ready,
      ),
    );

    // 🚀 네이티브 스트림 최적화
    _statusChannel.receiveBroadcastStream().listen((data) async {
      // 🚀 resume 직후 Surface/IME 재구성 중에는 신호 무시 (Input Channel 충돌 방지)
      if (_isSuppressed) return;
      try {
        if (data == null) return;
        final mediaData = Map<String, dynamic>.from(data);

        // 데이터 타입 안전하게 추출 (num으로 받고 toInt 처리)
        final String newTitle = mediaData['title']?.toString() ?? 'Unknown';
        final String newArtist = mediaData['artist']?.toString() ?? 'Unknown';
        final bool isPlaying = mediaData['isPlaying'] as bool? ?? false;
        final int incomingPos = (mediaData['position'] as num? ?? 0).toInt();
        final int durationMs = (mediaData['duration'] as num? ?? 0).toInt();

        // 0초 데이터 방어
        if (isPlaying && incomingPos <= 0 && mediaItem.value?.title == newTitle) return;

        // 재생 상태 업데이트
        playbackState.add(
          playbackState.value.copyWith(
            playing: isPlaying,
            updatePosition: Duration(milliseconds: incomingPos),
            bufferedPosition: Duration(milliseconds: incomingPos),
            speed: isPlaying ? 1.0 : 0.0,
          ),
        );

        // 곡 제목이 바뀌었을 때만 메타데이터/가사 갱신
        if (mediaItem.value?.title != newTitle) {
          mediaItem.add(
            MediaItem(
              id: 'external_media',
              album: 'External Player',
              title: newTitle,
              artist: newArtist,
              duration: Duration(milliseconds: durationMs),
            ),
          );
        }
      } catch (e) {
        debugPrint("🚨 리스너 에러 방어: $e"); // 에러가 나도 리스너는 죽지 않음
      }
    }, onError: (err) => debugPrint("🚨 스트림 에러: $err"));
  }

  Future<void> _invokeNativeMediaKey(int keyCode) async {
    try {
      await _nativeChannel.invokeMethod('sendMediaKey', {'keyCode': keyCode});
    } catch (e) {
      debugPrint("Native Bridge Error: $e");
    }
  }


  Future<void> refreshMetadata() async {
    try {
      // 안드로이드 네이티브 측에서 이 메서드명을 받아서 처리하도록 설정해야 합니다.
      await _nativeChannel.invokeMethod('requestMetadataRefresh');
      debugPrint("Metadata refresh requested to Native");
    } catch (e) {
      debugPrint("Refresh Bridge Error: $e");
    }
  }

  @override
  Future<void> play() async => await _invokeNativeMediaKey(126);
  @override
  Future<void> pause() async => await _invokeNativeMediaKey(127);
  @override
  Future<void> skipToNext() async => await _invokeNativeMediaKey(87);
  @override
  Future<void> skipToPrevious() async => await _invokeNativeMediaKey(88);
}

class GlasnylPlayer extends StatelessWidget {
  final bool isFirstRun;
  const GlasnylPlayer({super.key, required this.isFirstRun});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // 네오포키즘 베이스 컬러
        scaffoldBackgroundColor: const Color(0xFFE0E5EC),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Pretendard',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(letterSpacing: -0.5),
          bodyMedium: TextStyle(letterSpacing: -0.5),
        ),
      ),
      home: isFirstRun
          ? const OnboardingScreen()
          : const _MainRoute(),
      routes: {
        '/main': (context) => const _MainRoute(),
      },
    );
  }
}

/// home과 /main route가 같은 permissionGuardKey를 공유하면
/// 동시에 트리에 존재하는 순간 GlobalKey 충돌이 발생합니다.
/// _MainRoute로 분리하여 단일 진입점을 보장합니다.
class _MainRoute extends StatelessWidget {
  const _MainRoute();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data?.playing ?? false;
        return PermissionGuard(
          key: permissionGuardKey,
          isPlaying: isPlaying,
          child: const VinylPlayerScreen(),
        );
      },
    );
  }
}