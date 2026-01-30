import 'package:flutter/material.dart';
import '../models/player_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:flutter/foundation.dart';

class LayoutEngine {
  static PlayerConfig calculate(
    Size size,
    Orientation orientation,
    bool isPip,
  ) {

    final bool isFlipCover = size.width > size.height && size.width < 600;
    final bool isLandscape = orientation == Orientation.landscape && !isFlipCover;

        // 반응형 단위 계산
    double responsiveUnit = size.shortestSide;

    if (isPip) {
      // 1. 비율 설정 (2.3:1)
      final double cardWidth = size.width;
      final double cardHeight = size.width / 2.3;

      // 2. 앨범 사이즈 (높이의 80% 정도)
      double albumSize = cardHeight * 0.8;

      return PlayerConfig(
        lpSize: albumSize,
        needleSize: 0,
        titleSize: 15, // 글씨 조금 키움
        artistSize: 12,
        progressBarWidth: 0,
        playButtonsWidth: 0,

        // 🚀 앨범 아트: 왼쪽 배치 (x: 20%, y: 중앙)
        lpPos: Offset(cardWidth * 0.22, cardHeight * 0.5),

        // 🚀 제목/가수 위치 (수정):
        // 만약 Positioned로 그리신다면 이 좌표들이 카드 높이(cardHeight)를
        // 벗어나지 않도록 0.35, 0.6 정도로 타이트하게 잡아야 합니다.
        titlePos: Offset(cardWidth * 0.7, cardHeight * 0.4),
        artistPos: Offset(cardWidth * 0.7, cardHeight * 0.62),

        // 나머지는 화면 밖으로
        needlePos: const Offset(-500, -500),
        progressBarPos: const Offset(-500, -500),
        playButtonsPos: const Offset(-500, -500),
        prevButtonPos: const Offset(-500, -500),
        nextButtonPos: const Offset(-500, -500),

      );
    } else if (isLandscape) {
      // --- [가로 모드] 기존 디자인 유지 ---
      double lpSize = size.height * 0.75;
      double progressBarWidth = size.width * 0.35;
      double pbPosMidX = size.width * 0.7;
      double pbPosMidY = size.height * 0.8;

      return PlayerConfig(
        lpSize: lpSize,
        needleSize: size.height * 0.35,
        titleSize: responsiveUnit * 0.06,
        artistSize: responsiveUnit * 0.03,
        progressBarWidth: progressBarWidth,
        playButtonsWidth: size.width * 0.3,

        lpPos: Offset(size.width * 0.24, size.height * 0.54),
        needlePos: Offset(size.width * 0.30, size.height * 0.23),
        titlePos: Offset(size.width * 0.7, size.height * 0.25),
        artistPos: Offset(
          size.width * 0.7,
          size.height * 0.25 + (size.height * 0.08),
        ),
        progressBarPos: Offset(size.width * 0.7, size.height * 0.55),
        playButtonsPos: Offset(pbPosMidX, pbPosMidY),
        prevButtonPos: Offset(pbPosMidX - 80, pbPosMidY),
        nextButtonPos: Offset(pbPosMidX + 80, pbPosMidY),
      );
    }
    // 🚀 [추가] 플립 커버 전용 레이아웃 분기
    else if (isFlipCover) {
      double lpSize = size.height * 0.82;
      double pbPosMidX = size.width * 0.72;
      double pbPosMidY = size.height * 0.86;

      return PlayerConfig(
        lpSize: lpSize,
        needleSize: 0,
        titleSize: 16,
        artistSize: 12,
        progressBarWidth: size.width * 0.48,
        playButtonsWidth: size.width * 0.45,

        // 좌측 LP판, 우측 텍스트/컨트롤 배치
        lpPos: Offset(size.width * 0.25, size.height * 0.5),
        titlePos: Offset(size.width * 0.72, size.height * 0.28),
        artistPos: Offset(size.width * 0.72, size.height * 0.45),
        progressBarPos: Offset(size.width * 0.72, size.height * 0.68),
        playButtonsPos: Offset(pbPosMidX, pbPosMidY),
        prevButtonPos: Offset(pbPosMidX - 70, pbPosMidY),
        nextButtonPos: Offset(pbPosMidX + 70, pbPosMidY),
        needlePos: const Offset(-500, -500),
      );
    } else {
      // --- [세로 모드] 기존 감성 우측 배치 유지 ---
      double lpSize = size.width * 0.82;
      double pbPosMidX = size.width * 0.5;
      double pbPosMidY = size.height * 0.88;

      return PlayerConfig(
        lpSize: lpSize,
        needleSize: size.height * 0.22,
        titleSize: responsiveUnit * 0.1,
        artistSize: responsiveUnit * 0.04,
        progressBarWidth: size.width * 0.92,
        playButtonsWidth: size.width * 0.7,

        lpPos: Offset(size.width * 0.8, size.height * 0.35),
        needlePos: Offset(size.width * 0.88, size.height * 0.23),
        titlePos: Offset(size.width * 0.42, size.height * 0.65),
        artistPos: Offset(
          size.width * 0.42,
          size.height * 0.65 + (size.height * 0.06),
        ),
        progressBarPos: Offset(size.width * 0.5, size.height * 0.78),
        playButtonsPos: Offset(pbPosMidX, pbPosMidY),
        prevButtonPos: Offset(pbPosMidX - 80, pbPosMidY),
        nextButtonPos: Offset(pbPosMidX + 80, pbPosMidY),
      );
    }
  }

  /// 저장된 커스텀 레이아웃 데이터 초기화
  static Future<void> clearSavedLayout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('layout_config');
    debugPrint("레이아웃 저장 데이터 삭제 완료");
  }
}
