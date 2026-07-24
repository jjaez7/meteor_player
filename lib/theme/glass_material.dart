import 'dart:ui';
import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// ── 팝업 공용 껍데기 ────────────────────────────────────────────
/// 지금 각 다이얼로그(dialog_settings, dialog_creator 등)가 서로
/// 독립적으로 구현돼 있어서, 팝업 내부 로직은 그대로 두고 이 껍데기로
/// 바깥만 감싸면 "같은 디자인 시스템에 속한 팝업"처럼 통일됨.
/// 사용법: showDialog의 builder에서 기존 콘텐츠를
/// `GlassPopupShell(child: 기존_다이얼로그_내용)`으로 한 겹만 감싸면 됨 —
/// 내부 버튼/로직/상태는 전혀 안 건드려도 됨.
class GlassPopupShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;

  const GlassPopupShell({
    super.key,
    required this.child,
    this.maxWidth = 340,
    this.accentColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: GSpace.xl,
        vertical: GSpace.xxl,
      ),
      child: TweenAnimationBuilder<double>(
        // Popup motion 토큰: scale + opacity, 한 종류로 통일
        duration: GMotion.popupDuration,
        curve: GMotion.popupCurve,
        tween: Tween(begin: 0.94, end: 1.0),
        builder: (context, scale, _) {
          return Opacity(
            opacity: ((scale - 0.94) / 0.06).clamp(0.0, 1.0),
            child: Transform.scale(scale: scale, child: _shell(context)),
          );
        },
      ),
    );
  }

  Widget _shell(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GRadius.popup),
          boxShadow: GShadow.forLevel(GElevation.popup),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(GRadius.popup),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), // 팝업은 배경과 확실히 분리되도록 조금 더 진하게
            child: Container(
            padding: padding ?? const EdgeInsets.all(GSpace.xl),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GRadius.popup),
                color: const Color(0xFF1C1B20).withValues(alpha: 0.55),
                border: Border.all(
                  color: (accentColor ?? Colors.white).withValues(alpha: 0.18),
                  width: 1.0,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// ════════════════════════════════════════════════════════════
/// GLASS MATERIAL
/// "Clear glass instead of foggy glass." 앱 전체 글래스 컴포넌트가
/// 공유하는 하나의 재질. 카드마다 제각각 blur/border/그림자를 쓰지
/// 않고, 전부 이 위젯을 통해서만 글래스 표면을 만든다.
///
/// 구성 요소:
///  - blur: 기존보다 약하게 (진한 안개 대신 맑은 유리)
///  - top highlight: 위쪽에서 빛이 스치는 듯한 아주 옅은 밝은 띠
///  - thin border: 얇은 유리 테두리
///  - internal gradient: 표면 안쪽에 미세한 톤 변화
///  - specular reflection: 좌상단 쪽 작은 하이라이트 점
///  - Fresnel edge: 가장자리로 갈수록 살짝 밝아지는 광학적 느낌
/// ════════════════════════════════════════════════════════════
class GlassMaterial extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final GElevation elevation;
  final double blurSigma;
  final Color tint;
  final double tintOpacity;
  final EdgeInsetsGeometry? padding;
  final Color? accentColor; // 지정 시 은은한 accent 톤을 유리에 섞음
  final Color? borderColorOverride; // 지정 시 Fresnel 톤 대신 이 색을 그대로 사용 (상태 반응형 테두리용)
  final double borderWidth;
  final double? width;
  final double? height;

  const GlassMaterial({
    super.key,
    required this.child,
    this.borderRadius = GRadius.largeCard,
    this.elevation = GElevation.card,
    this.blurSigma = 6, // 기존 10 → 더 맑게
    this.tint = Colors.white,
    this.tintOpacity = 0.07,
    this.padding,
    this.accentColor,
    this.borderColorOverride,
    this.borderWidth = 1.0,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: GShadow.forLevel(elevation),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            width: width,
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              // 내부 그라데이션: 위는 살짝 밝고 아래로 갈수록 가라앉는 톤
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tint.withValues(alpha: tintOpacity + 0.03),
                  tint.withValues(alpha: tintOpacity),
                  tint.withValues(alpha: tintOpacity - 0.02 < 0 ? 0.0 : tintOpacity - 0.02),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(
                // Fresnel: 얇고 밝은 테두리 — accent가 있으면 아주 살짝 섞음
                // borderColorOverride가 있으면 상태 반응형 색을 그대로 사용
                color: borderColorOverride ??
                    (accentColor ?? Colors.white)
                        .withValues(alpha: accentColor != null ? 0.16 : 0.14),
                width: borderWidth,
              ),
            ),
            child: Stack(
              children: [
                child,
                // 상단 하이라이트: 유리 위쪽에서 빛이 스치는 느낌
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 1.0,
                      margin: EdgeInsets.symmetric(horizontal: borderRadius * 0.5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 좌상단 스페큘러 하이라이트: 아주 작고 옅은 반사광 하나
                Positioned(
                  top: -borderRadius * 0.6,
                  left: -borderRadius * 0.6,
                  child: IgnorePointer(
                    child: Container(
                      width: borderRadius * 2.2,
                      height: borderRadius * 2.2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.10),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}