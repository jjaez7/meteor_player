import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════
/// GLASNYL DESIGN TOKENS
/// "Never use random values." — 프리미엄 리파인 프롬프트의 핵심 원칙.
/// radius, spacing, motion, elevation을 전부 이 파일의 스케일에서만
/// 가져다 쓴다. 새 화면/컴포넌트를 만들 때도 여기 없는 임의의 숫자를
/// 쓰지 않는 것이 이 시스템의 존재 이유.
/// ════════════════════════════════════════════════════════════

/// ── Radius Scale ───────────────────────────────────────────────
class GRadius {
  GRadius._();
  static const double button = 999; // pill / 완전 원형
  static const double sliderThumb = 16;
  static const double mediumCard = 24; // 시계, 가사 카드 등
  static const double largeCard = 28; // LP, 정보 패널 등
  static const double popup = 32;
}

/// ── Spacing Scale (4의 배수) ───────────────────────────────────
class GSpace {
  GSpace._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

/// ── Elevation / Depth 레벨 ─────────────────────────────────────
/// 레벨이 높을수록 그림자가 크고 진해짐. 모든 카드가 같은 그림자를
/// 쓰지 않도록, 컴포넌트 종류별로 레벨을 지정해서 쓴다.
enum GElevation {
  ambient, // 배경 바로 위 (거의 그림자 없음)
  soft, // 시계처럼 가벼운 카드
  medium, // 볼륨 카드
  card, // 일반 글래스 카드
  lp, // LP — 가장 큰 그림자
  floating, // 플로팅 컨트롤
  popup, // 팝업 — 가장 높은 elevation
  glow, // glow 레이어 (그림자 아닌 발광)
}

class GShadow {
  GShadow._();

  static List<BoxShadow> forLevel(GElevation level, {Color color = Colors.black}) {
    switch (level) {
      case GElevation.ambient:
        return [];
      case GElevation.soft:
        return [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
      case GElevation.medium:
        return [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 11,
            offset: const Offset(0, 3),
          ),
        ];
      case GElevation.card:
        return [
          BoxShadow(
            color: color.withValues(alpha: 0.09),
            blurRadius: 11,
            offset: const Offset(0, 3),
          ),
        ];
      case GElevation.lp:
        return [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ];
      case GElevation.floating:
        return [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ];
      case GElevation.popup:
        return [
          BoxShadow(
            color: color.withValues(alpha: 0.32),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ];
      case GElevation.glow:
        return [];
    }
  }
}

/// ── Motion 시스템 ──────────────────────────────────────────────
/// "Every animation should belong to one motion language."
/// duration/curve 조합을 컴포넌트 종류별로 하나씩만 허용.
class GMotion {
  GMotion._();

  // Button: 작은 scale
  static const Duration buttonDuration = Duration(milliseconds: 140);
  static const Curve buttonCurve = Curves.easeOut;

  // Card: fade + scale
  static const Duration cardDuration = Duration(milliseconds: 380);
  static const Curve cardCurve = Curves.easeOutCubic;

  // Popup: scale + opacity
  static const Duration popupDuration = Duration(milliseconds: 260);
  static const Curve popupCurve = Curves.easeOutCubic;

  // Lyrics: opacity + 살짝 translation
  static const Duration lyricsDuration = Duration(milliseconds: 320);
  static const Curve lyricsCurve = Curves.easeOutCubic;

  // Album/trans: crossfade + scale
  static const Duration albumTransitionDuration = Duration(milliseconds: 420);
  static const Curve albumTransitionCurve = Curves.easeOutCubic;

  // Ambient: 느린 숨쉬기
  static const Duration ambientBreathe = Duration(milliseconds: 9000);
}

/// ── Typography 계층 ────────────────────────────────────────────
/// 곡 제목 > 아티스트 > 메타데이터. weight/opacity/letterSpacing을
/// 이 세 단계에서만 골라 쓴다.
class GType {
  GType._();

  static TextStyle title({
    required double fontSize,
    Color color = Colors.white,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -0.5,
        height: 1.15,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      );

  static TextStyle artist({
    required double fontSize,
    Color color = Colors.white,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color.withValues(alpha: 0.62),
        letterSpacing: 1.6,
        height: 1.2,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, 1),
            blurRadius: 6,
          ),
        ],
      );

  static TextStyle metadata({
    required double fontSize,
    Color color = Colors.white,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: color.withValues(alpha: 0.40),
        letterSpacing: 0.8,
        height: 1.2,
      );
}