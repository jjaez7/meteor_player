import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mp_design/permission_guard.dart';
import 'player_screen.dart';
import 'onboarding_screen.dart';

late MyAudioHandler audioHandler;

void main() async {
  // 1. 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 초기 로드 (병렬 처리로 시간 단축)
  final results = await Future.wait([
    SharedPreferences.getInstance(),
    AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.meteor.player.audio',
        androidNotificationChannelName: 'Meteor Player Control',
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
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(MeteorPlayer(isFirstRun: isFirstRun));
}

class MyAudioHandler extends BaseAudioHandler {
  static const MethodChannel _nativeChannel = MethodChannel('com.meteor.player/media_control');
  static const EventChannel _statusChannel = EventChannel('com.meteor.player/media_status');

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
    _statusChannel.receiveBroadcastStream().listen((data) {
      final mediaData = Map<String, dynamic>.from(data);
      final bool isPlaying = mediaData['isPlaying'] ?? false;
      final String newTitle = mediaData['title'] ?? 'Unknown';

      // 1. 재생 상태 업데이트 (포지션 정보는 자주 바뀌어도 됨)
      playbackState.add(playbackState.value.copyWith(
        playing: isPlaying,
        updatePosition: Duration(milliseconds: mediaData['position'] as int),
        bufferedPosition: Duration(milliseconds: mediaData['position'] as int),
        speed: isPlaying ? 1.0 : 0.0,
      ));

      // 2. 🚀 미디어 아이템 업데이트 (제목이 바뀌었을 때만 수행하여 렉 방지)
      if (mediaItem.value?.title != newTitle) {
        mediaItem.add(
          MediaItem(
            id: 'external_media',
            album: 'External Player',
            title: newTitle,
            artist: mediaData['artist'] ?? 'Unknown',
            duration: Duration(milliseconds: mediaData['duration'] as int),
          ),
        );
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

  @override
  Future<void> play() async => await _invokeNativeMediaKey(126);
  @override
  Future<void> pause() async => await _invokeNativeMediaKey(127);
  @override
  Future<void> skipToNext() async => await _invokeNativeMediaKey(87);
  @override
  Future<void> skipToPrevious() async => await _invokeNativeMediaKey(88);
}

class MeteorPlayer extends StatelessWidget {
  final bool isFirstRun;
  const MeteorPlayer({super.key, required this.isFirstRun});

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
          : PermissionGuard(child: const VinylPlayerScreen()),
      routes: {
        '/main': (context) => PermissionGuard(child: const VinylPlayerScreen()),
      },
    );
  }
}