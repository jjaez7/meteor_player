import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

// [제목 위젯] 
// 요즘 대세인 'Bold 화이트 + 소프트 섀도우' 스타일
class MarqueeTitleWidget extends StatelessWidget {
  final String title;
  final double fontSize;
  // 글래스모피즘에서는 사실 텍스트 컬러를 흰색 고정으로 쓰는 것이 가장 예쁘지만,
  // 유연성을 위해 인자로 받되 내부에서 보정합니다.
  final Color textColor;

  const MarqueeTitleWidget({
    super.key,
    required this.title,
    required this.fontSize,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    // 🚀 포인트: ShaderMask를 제거하고 '순백색'의 대비를 극대화합니다.
    return Marquee(
      key: Key(title),
      text: title,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900, // 더 두껍고 단단한 느낌
        color: Colors.white, // 쨍한 화이트로 시인성 확보
        letterSpacing: -0.5,
        shadows: [
          // 🚀 소프트 레이어 섀도우: 입체감이 아니라 '글자가 떠 있는 안개' 느낌
          Shadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      blankSpace: 300.0,
      velocity: 50.0,
      pauseAfterRound: const Duration(seconds: 3),
      // 부드러운 가속도를 주어 기계적인 느낌을 뺍니다.
      accelerationDuration: const Duration(milliseconds: 500),
      accelerationCurve: Curves.easeInOut,
    );
  }
}

// [가수 위젯]
// 메인 제목을 보조하는 투명도 높은 서브 텍스트 스타일
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
        // 🚀 포인트: 화이트에 가까운 투명 컬러를 사용하여 '계층'을 나눕니다.
        color: Colors.white.withValues(alpha: 0.6),
        fontWeight: FontWeight.w600,
        letterSpacing: 2.0,
        fontFamily: 'sans-serif-medium',
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}