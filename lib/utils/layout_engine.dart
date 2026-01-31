import 'package:flutter/material.dart';
import '../models/player_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LayoutEngine {
  /// 🚀 바늘 위치를 LP판의 크기에 맞춰 상대적으로 계산
  static Offset calculateNeedlePos(Offset lpPos, double lpSize) {
    double radius = lpSize / 2;
    const double xGap = 0.32; 
    const double yGap = 0.72;

    return Offset(
      lpPos.dx + (radius * xGap),
      lpPos.dy - (radius * yGap),
    );
  }

  static PlayerConfig calculate(
    Size size,
    Orientation orientation,
    bool isPip,
  ) {
    final bool isFlipCover = size.width > size.height && size.width < 600;
    final bool isLandscape = orientation == Orientation.landscape && !isFlipCover;

    double responsiveUnit = size.shortestSide;

    if (isPip) {
      final double cardWidth = size.width;
      final double cardHeight = size.width / 2.3;
      double albumSize = cardHeight * 0.8;
      Offset lpPos = Offset(cardWidth * 0.22, cardHeight * 0.5);

      return PlayerConfig(
        lpSize: albumSize,
        needleSize: 0,
        titleSize: 15,
        artistSize: 12,
        progressBarWidth: 0,
        playButtonsWidth: 0,
        lpPos: lpPos,
        titlePos: Offset(cardWidth * 0.7, cardHeight * 0.4),
        artistPos: Offset(cardWidth * 0.7, cardHeight * 0.62),
        needlePos: const Offset(-500, -500),
        progressBarPos: const Offset(-500, -500),
        playButtonsPos: const Offset(-500, -500),
        prevButtonPos: const Offset(-500, -500),
        nextButtonPos: const Offset(-500, -500),
      );
    } else if (isLandscape) {
      // --- [가로 모드] ---
      // LP 사이즈 제한 완화: 500 -> 650
      double lpSize = size.height * 0.75;
      if (lpSize > 650) lpSize = 650; 

      // 텍스트 사이즈 제한 완화
      double titleSize = responsiveUnit * 0.06;
      if (titleSize > 50) titleSize = 50;
      double artistSize = responsiveUnit * 0.03;
      if (artistSize > 25) artistSize = 25;

      Offset lpPos = Offset(size.width * 0.24, size.height * 0.54);
      double pbPosMidX = size.width * 0.7;
      double pbPosMidY = size.height * 0.8;

      return PlayerConfig(
        lpSize: lpSize,
        needleSize: size.height * 0.35,
        titleSize: titleSize,
        artistSize: artistSize,
        progressBarWidth: size.width * 0.35,
        playButtonsWidth: size.width * 0.3,
        lpPos: lpPos,
        needlePos: calculateNeedlePos(lpPos, lpSize),
        titlePos: Offset(size.width * 0.7, size.height * 0.25),
        artistPos: Offset(size.width * 0.7, size.height * 0.25 + (size.height * 0.08)),
        progressBarPos: Offset(size.width * 0.7, size.height * 0.55),
        playButtonsPos: Offset(pbPosMidX, pbPosMidY),
        prevButtonPos: Offset(pbPosMidX - 80, pbPosMidY),
        nextButtonPos: Offset(pbPosMidX + 80, pbPosMidY),
      );
    } else if (isFlipCover) {
      return PlayerConfig(
        lpSize: size.height * 0.82,
        needleSize: 0,
        titleSize: 16,
        artistSize: 12,
        progressBarWidth: size.width * 0.48,
        playButtonsWidth: size.width * 0.45,
        lpPos: Offset(size.width * 0.25, size.height * 0.5),
        titlePos: Offset(size.width * 0.72, size.height * 0.28),
        artistPos: Offset(size.width * 0.72, size.height * 0.45),
        progressBarPos: Offset(size.width * 0.72, size.height * 0.68),
        playButtonsPos: Offset(size.width * 0.72, size.height * 0.86),
        prevButtonPos: Offset(size.width * 0.72 - 70, size.height * 0.86),
        nextButtonPos: Offset(size.width * 0.72 + 70, size.height * 0.86),
        needlePos: const Offset(-500, -500),
      );
    } else {
      // --- [세로 모드] ---
      // LP 사이즈 제한 완화: 450 -> 580 (패드 세로에서도 넉넉하게)
      double lpSize = size.width * 0.82;
      if (lpSize > 580) lpSize = 580; 

      // 텍스트 사이즈 제한 완화
      double titleSize = responsiveUnit * 0.1;
      if (titleSize > 60) titleSize = 60; 
      double artistSize = responsiveUnit * 0.04;
      if (artistSize > 30) artistSize = 30;

      Offset lpPos = Offset(size.width * 0.8, size.height * 0.35);
      double pbPosMidX = size.width * 0.5;
      double pbPosMidY = size.height * 0.88;

      return PlayerConfig(
        lpSize: lpSize,
        needleSize: size.height * 0.22,
        titleSize: titleSize,
        artistSize: artistSize,
        progressBarWidth: size.width * 0.92,
        playButtonsWidth: size.width * 0.7,
        lpPos: lpPos,
        needlePos: calculateNeedlePos(lpPos, lpSize),
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

  static Future<void> clearSavedLayout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('layout_config');
    debugPrint("레이아웃 저장 데이터 삭제 완료");
  }
}