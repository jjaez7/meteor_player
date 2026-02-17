import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glasnyl/permission_guard.dart';
import 'player_screen.dart';
import 'onboarding_screen.dart';
import 'services/lyrics_service.dart';
import 'models/lyric_model.dart';


String appVersion="1.0.0";

late MyAudioHandler audioHandler;
final GlobalKey<PermissionGuardState> permissionGuardKey = GlobalKey<PermissionGuardState>();
void main() async {
  // 1. 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  final packageInfo = await PackageInfo.fromPlatform();
  appVersion = packageInfo.version;

  // 2. 초기 로드 (병렬 처리로 시간 단축)
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

  // 3. UI 설정 (비동기로 실행하여 렌더링 시작을 앞당김)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(GlasnylPlayer(isFirstRun: isFirstRun));
}


class MyAudioHandler extends BaseAudioHandler {
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.glasnyl.app/media_control',
  );
  static const EventChannel _statusChannel = EventChannel(
    'com.glasnyl.app/media_status',
  );

  List<LyricLine> currentLyrics = [];
  Stream<Duration> get position => playbackState.map((state) => state.updatePosition).distinct();
  
  // (옵션) 전체 길이 스트림도 있으면 편합니다.
  Stream<Duration> get duration => mediaItem.map((item) => item?.duration ?? Duration.zero).distinct();
  
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
    _statusChannel.receiveBroadcastStream().listen((data) async{
      final mediaData = Map<String, dynamic>.from(data);
      final bool isPlaying = mediaData['isPlaying'] ?? false;
      final String newTitle = mediaData['title'] ?? 'Unknown';
      final String newArtist = mediaData['artist'] ?? 'Unknown';
      final int incomingPos = mediaData['position'] as int;

      // 🚀 [수정 핵심] 시스템이 보내는 0초 데이터를 방어합니다.
      // 재생 중인데 갑자기 0이 들어오면 무시하고 리턴합니다.
      if (isPlaying && incomingPos <= 0) {
        // debugPrint("🚫 핸들러: 시스템의 잘못된 0초 신호 차단");
        return; // 이 신호는 무시하고 다음 신호를 기다립니다.
      }

      // 1. 재생 상태 업데이트 (포지션 정보는 자주 바뀌어도 됨)
      playbackState.add(
        playbackState.value.copyWith(
          playing: isPlaying,
          updatePosition: Duration(milliseconds: incomingPos),
          bufferedPosition: Duration(milliseconds: incomingPos),
          speed: isPlaying ? 1.0 : 0.0,
        ),
      );

      // 2. 🚀 미디어 아이템 업데이트 (제목이 바뀌었을 때만 수행하여 렉 방지)
      if (mediaItem.value?.title != newTitle) {
        mediaItem.add(
          MediaItem(
            id: 'external_media',
            album: 'External Player',
            title: newTitle,
            artist: newArtist,
            duration: Duration(milliseconds: mediaData['duration'] as int),
          ),
        );
        _updateLyrics(newTitle, newArtist);
      }
    });
  }

  Future<void> _invokeNativeMediaKey(int keyCode) async {
    try {
      await _nativeChannel.invokeMethod('sendMediaKey', {'keyCode': keyCode});
    } catch (e) {
      debugPrint("Native Bridge Error: $e");
    }
  }

  Future<void> _updateLyrics(String title, String artist) async {
    try {
      final result = await LyricsService.getLyrics(title, artist);
      currentLyrics = result.lyrics;
      
      // UI에 가사가 업데이트되었음을 알리기 위해 
      // 필요하다면 가사 전용 Stream을 만들거나 mediaItem을 다시 한번 쏴줄 수 있습니다.
      debugPrint("✅ Lyrics loaded: ${currentLyrics.length} lines (Status: ${result.status.name})");
    } catch (e) {
      debugPrint("🚨 Lyrics Update Error: $e");
      currentLyrics = [];
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
          : StreamBuilder<PlaybackState>(
              stream: audioHandler.playbackState,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data?.playing ?? false;
                return PermissionGuard(
                  key: permissionGuardKey,
                  isPlaying: isPlaying,
                  child: const VinylPlayerScreen(),
                );
              },
            ),
      routes: {
        // 🚀 routes 부분도 StreamBuilder를 추가하여 일관성을 맞췄습니다.
        '/main': (context) => StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data?.playing ?? false;
            return PermissionGuard(
              key: permissionGuardKey,
              isPlaying: isPlaying,
              child: const VinylPlayerScreen(),
            );
          },
        ),
      },
    );
  }
}
