import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 추가
import 'package:mp_design/permission_guard.dart';
import 'player_screen.dart';
import 'onboarding_screen.dart'; // 추가

late MyAudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. SharedPreferences를 통해 첫 실행 여부 확인
  final prefs = await SharedPreferences.getInstance();
  final bool isFirstRun = prefs.getBool('isFirstRun') ?? true;

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.meteor.player.audio',
      androidNotificationChannelName: 'Meteor Player Control',
      androidShowNotificationBadge: true,
      androidStopForegroundOnPause: false,
    ),
  );

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

  // 2. 실행 시 첫 실행 여부를 전달
  runApp(MeteorPlayer(isFirstRun: isFirstRun));
}

class MyAudioHandler extends BaseAudioHandler {
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.meteor.player/media_control',
  );

  static const EventChannel _statusChannel = EventChannel(
    'com.meteor.player/media_status',
  );

  MyAudioHandler() {
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

    _statusChannel.receiveBroadcastStream().listen((data) {
      final mediaData = Map<String, dynamic>.from(data);
      final bool isPlaying = mediaData['isPlaying'] ?? false;

      playbackState.add(playbackState.value.copyWith(
        playing: isPlaying,
        updatePosition: Duration(milliseconds: mediaData['position'] as int),
        bufferedPosition: Duration(milliseconds: mediaData['position'] as int),
        speed: isPlaying ? 1.0 : 0.0,
      ));

      mediaItem.add(
        MediaItem(
          id: 'external_media',
          album: 'External Player',
          title: mediaData['title'] ?? 'Unknown',
          artist: mediaData['artist'] ?? 'Unknown',
          duration: Duration(milliseconds: mediaData['duration'] as int),
        ),
      );
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
  final bool isFirstRun; // 추가
  const MeteorPlayer({super.key, required this.isFirstRun}); // 수정

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // 네오포키즘 베이스 컬러 (onboarding_screen과 일치)
        scaffoldBackgroundColor: const Color(0xFFE0E5EC), 
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Pretendard',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(letterSpacing: -0.5),
          bodyMedium: TextStyle(letterSpacing: -0.5),
        ),
      ),
      // 3. 첫 실행이면 온보딩, 아니면 메인 화면(PermissionGuard)으로 연결
      home: isFirstRun 
          ? const OnboardingScreen() 
          : PermissionGuard(child: const VinylPlayerScreen()),
      routes: {
        '/main': (context) => PermissionGuard(child: const VinylPlayerScreen()),
      },
    );
  }
}