import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/player_logic.dart'; // 경로 확인 필수!
import 'player_elements.dart'; // ProgressBarWidget이 정의된 파일 경로

class StreamProgressBar extends StatelessWidget {
  final double barWidth;
  final Color bgColor;
  final Color barColor;
  final Function(double ratio)? onSeek;

  const StreamProgressBar({
    super.key,
    required this.barWidth,
    required this.bgColor,
    required this.barColor,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      // 부모 위젯과 별개로 이 스트림만 감시합니다.
      stream: const EventChannel('com.meteor.player/media_status').receiveBroadcastStream(),
      builder: (context, snapshot) {
        double currentFactor = 0.0;
        int duration = 1;

        if (snapshot.hasData && snapshot.data != null) {
          try {
            final data = Map<String, dynamic>.from(snapshot.data);
            if (data.containsKey('position') && data.containsKey('duration')) {
              final int pos = data['position'] ?? 0;
              final int dur = data['duration'] ?? 1;
              currentFactor = (pos / dur).clamp(0.0, 1.0);
            }
          } catch (e) {
            debugPrint("Progress factor calculation error: $e");
          }
        }

        // 튕김 방지 로직이 들어있는 기존 위젯 호출
        return ProgressBarWidget(
          width: barWidth,
          factor: currentFactor,
          bgColor: bgColor,
          barColor: barColor,
          onSeek: (newRatio) {
            if (onSeek != null) {
              onSeek!(newRatio);
            } else {
              PlayerLogic.seekTo(newRatio); // 기본 동작
            }
          },
        );
      },
    );
  }
}