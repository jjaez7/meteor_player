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
    return LayoutBuilder(
      builder: (context, constraints) {
        // 실제 렌더된 너비를 우선 사용. 0이거나 무한이면 barWidth 폴백.
        final double realWidth = (constraints.maxWidth > 0 && constraints.maxWidth != double.infinity)
            ? constraints.maxWidth
            : barWidth;

        return StreamBuilder(
          stream: const EventChannel('com.glasnyl.app/media_status').receiveBroadcastStream(),
          builder: (context, snapshot) {
            double currentFactor = 0.0;

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

            return ProgressBarWidget(
              width: realWidth,
              factor: currentFactor,
              bgColor: bgColor,
              barColor: barColor,
              onSeek: (newRatio) {
                if (onSeek != null) {
                  onSeek!(newRatio);
                } else {
                  PlayerLogic.seekTo(newRatio);
                }
              },
            );
          },
        );
      },
    );
  }
}