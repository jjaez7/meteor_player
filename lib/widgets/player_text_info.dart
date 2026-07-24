import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import '../theme/design_tokens.dart';

// [제목 위젯]
// 짧으면 고정, 길어서 화면 밖으로 나가면 전광판 모드
class MarqueeTitleWidget extends StatelessWidget {
  final String title;
  final double fontSize;
  final Color textColor;
  final double? width;
  final bool isPip;

  const MarqueeTitleWidget({
    super.key,
    required this.title,
    required this.fontSize,
    required this.textColor,
    this.isPip = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isFlipCover = size.width > size.height && size.width < 600;

    // 공통 스타일 정의 — 디자인 시스템의 title 토큰 사용 (일관된 계층/그림자)
    // 주의: 기존처럼 항상 흰색 유지 (textColor 값을 실제로 쓰면 동작이 바뀌므로 그대로 보존)
    final TextStyle textStyle = GType.title(fontSize: fontSize);

    if (isPip) {
      return Text(
        title,
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis, // 말줄임표(...) 처리
      );
    }

    // 🚀 핵심 로직: LayoutBuilder를 통해 부모가 준 width 안에서 글자가 넘치는지 판단
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = (constraints.maxWidth == double.infinity || constraints.maxWidth <= 0)
        ? MediaQuery.of(context).size.width * 0.8 // 최소한의 방어선
        : constraints.maxWidth;

        // 글자의 실제 가로 길이를 미리 계산
        final textPainter = TextPainter(
          text: TextSpan(text: title, style: textStyle),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        // 넘칠 때만 Marquee 실행, 아니면 일반 Text 반환
        if (textPainter.width > (availableWidth + 1.2)) {
          return SizedBox(
            height: fontSize * 1.5,
            child: Marquee(
              key: Key(title),
              text: title,
              style: textStyle,
              blankSpace: isFlipCover ? 50.0 : 100.0, // 넘칠 때 이어지는 간격
              velocity: 50.0,
              pauseAfterRound: const Duration(seconds: 3),
              accelerationDuration: const Duration(milliseconds: 500),
              accelerationCurve: Curves.easeInOut,
            ),
          );
        } else {
          return Text(
            title,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
          );
        }
      },
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
    final size = MediaQuery.of(context).size;
    final bool isFlipCover = size.width > size.height && size.width < 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 부모가 유한한 너비를 주면 그것을, 아니면 화면 80%를 상한으로 사용
        final double maxW = (constraints.maxWidth.isFinite && constraints.maxWidth > 0)
            ? constraints.maxWidth
            : size.width * 0.8;

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Text(
            artist.toUpperCase(),
            textAlign: TextAlign.left,
            maxLines: isFlipCover ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            // 주의: 기존처럼 흰색 유지 (color 파라미터를 실제로 적용하면
            // 동작이 바뀌므로, 토큰의 그림자/굵기만 가져오고 색상은 보존)
            style: GType.artist(
              fontSize: isFlipCover ? fontSize * 0.9 : fontSize,
            ).copyWith(
              letterSpacing: isFlipCover ? 1.0 : 2.0,
              fontFamily: 'sans-serif-medium',
            ),
          ),
        );
      },
    );
  }
}