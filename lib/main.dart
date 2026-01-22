import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'player_screen.dart';

late MyAudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const MeteorPlayer());
}

class MyAudioHandler extends BaseAudioHandler {
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.meteor.player/media_control',
  );

  // 1. 실시간 상태를 받기 위한 EventChannel 추가
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

    // 2. 네이티브로부터의 상태 업데이트를 구독하여 audioHandler의 메타데이터 갱신
    _statusChannel.receiveBroadcastStream().listen((data) {
      final mediaData = Map<String, dynamic>.from(data);

      // 현재 재생 정보를 audio_service 내부 상태로 동기화 (선택 사항이지만 권장)
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
  const MeteorPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Pretendard',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(letterSpacing: -0.5),
          bodyMedium: TextStyle(letterSpacing: -0.5),
        ),
      ),
      home: const VinylPlayerScreen(),
    );
  }
}
