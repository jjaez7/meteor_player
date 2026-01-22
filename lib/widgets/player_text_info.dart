import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

// 제목 위젯
class MarqueeTitleWidget extends StatelessWidget {
  final String title;
  final double fontSize;
  final Color textColor;

  const MarqueeTitleWidget({
    super.key,
    required this.title,
    required this.fontSize,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: [textColor, textColor.withValues(alpha: 0.7)],
      ).createShader(bounds),
      child: Marquee(
        key: Key(title),
        text: title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -1.0,
        ),
        // [수정 포인트 1] 화면 너비보다 충분히 큰 여백을 주어 끝부분 노출 방지
        blankSpace: 300.0, 
        velocity: 50.0,
        // [수정 포인트 2] 멈췄을 때의 정지 시간을 확실히 보장
        pauseAfterRound: const Duration(seconds: 3), 
        // [수정 포인트 3] 가속/감속 시간을 0으로 설정하면 위치가 더 정확해집니다.
        // 만약 부드러운 시작을 원하면 아주 짧게(0.2초)만 주세요.
        accelerationDuration: Duration.zero, 
        decelerationDuration: Duration.zero,
        accelerationCurve: Curves.linear,
      ),
    );
  }
}

// 가수 위젯
class ArtistTextWidget extends StatelessWidget {
  final String artist;
  final double fontSize;
  final Color color;

  const ArtistTextWidget({
    super.key,
    required this.artist,
    required this.fontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      artist.toUpperCase(),
      textAlign: TextAlign.left,
      style: TextStyle(
        fontSize: fontSize,
        color: color.withValues(alpha: 0.7),
        fontWeight: FontWeight.w600,
        letterSpacing: 2.5,
        fontFamily: 'sans-serif-light',
        shadows: [
          Shadow(
            color: Colors.white.withValues(alpha: 0.5),
            offset: const Offset(-1, -1),
            blurRadius: 1,
          ),
          Shadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(1, 1),
            blurRadius: 1,
          ),
        ],
      ),
    );
  }
}
