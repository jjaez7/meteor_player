// lib/utils/layout_engine.dart

import 'package:flutter/material.dart';
import '../models/player_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class LayoutEngine {
  static PlayerConfig calculate(Size size, Orientation orientation) {
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      // --- 가로 모드: 왼쪽(LP) + 오른쪽(정보 및 제어) 분리형 레이아웃 ---
      // 가로 모드는 높이가 낮으므로 세로 높이 기준으로 크기를 결정합니다.
      double lpSize = size.height * 0.75; 
      double progressBarWidth = size.width * 0.35; 

      return PlayerConfig(
        lpSize: lpSize,
        // 바늘이 LP판 중심까지 충분히 닿을 수 있는 길이
        needleSize: size.height * 0.35, 
        titleSize: 28,
        artistSize: 14,
        progressBarWidth: progressBarWidth, // 오른쪽 영역 너비의 대부분 차지
        playButtonsWidth: 240,

        // 1. LP 위치: 왼쪽 영역(30%) 중앙에 배치
        lpPos: Offset(size.width * 0.24, size.height * 0.54),

        // 2. 바늘 위치: LP판의 오른쪽 상단 지점에 조인트 배치
        // LP 중심축 기준으로 자연스럽게 내려오도록 조정
        needlePos: Offset(size.width * 0.30, size.height * 0.23),

        // 3. 텍스트 위치: 오른쪽 영역 상단
        titlePos: Offset(size.width * 0.7, size.height * 0.25),
        artistPos: Offset(size.width * 0.7, size.height * 0.25 + 38),

        // 4. 프로그레스 바: 오른쪽 영역 중앙
        progressBarPos: Offset(size.width * 0.7, size.height * 0.55),

        // 5. 재생 버튼: 오른쪽 영역 하단
        playButtonsPos: Offset(size.width * 0.7, size.height * 0.8),
      );
    } else {
      // --- 세로 모드: 고퀄리티 바늘 디자인 대응 버전 ---
      double lpSize = size.width * 0.82; 

      return PlayerConfig(
        lpSize: lpSize,
        needleSize: size.height * 0.22,
        titleSize: 42,
        artistSize: 15,
        progressBarWidth: size.width * 0.92,
        playButtonsWidth: size.width * 0.7,

        // LP 위치: 살짝 오른쪽 아래로 내려서 안정감 부여
        lpPos: Offset(size.width * 0.8, size.height * 0.35),

        // 바늘 회전축 위치: 새로운 디자인의 '회전축 조인트'가 LP판 오른쪽 위에 오도록 조정
        needlePos: Offset(size.width * 0.88, size.height * 0.23),

        titlePos: Offset(size.width * 0.42, size.height * 0.65),
        artistPos: Offset(size.width * 0.42, size.height * 0.65 + 45),
        progressBarPos: Offset(size.width * 0.5, size.height * 0.78),
        playButtonsPos: Offset(size.width * 0.5, size.height * 0.88),
      );
    }
  }

  /// 저장된 커스텀 레이아웃 데이터 초기화
  static Future<void> clearSavedLayout() async {
    final prefs = await SharedPreferences.getInstance();
    // SharedPreferences에 저장할 때 사용한 키값('layout_config')과 동일해야 합니다.
    await prefs.remove('layout_config');
    debugPrint("레이아웃 저장 데이터 삭제 완료");
  }
}