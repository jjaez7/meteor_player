import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// ════════════════════════════════════════════════════════════
/// FLUID KIT
/// Samsung "Fluid AI Design System" 철학(카드 모핑, 컨텍스트 반응형
/// 레이아웃, glow 포커스, 비대칭 레이어링)을 GLASNYL의 글래스모피즘
/// + 바이닐 정체성 위에 재해석한 재사용 가능 위젯 모음.
///
/// 사용 원칙:
/// - 색/재질(blur, 반투명, 바이닐 텍스처)은 기존 GLASNYL 스타일 유지
/// - 형태 변형 방식(모핑, glow, 레이어링)만 이 키트에서 가져와 적용
/// ════════════════════════════════════════════════════════════

/// ── 1. 카드 모핑 컨테이너 ──────────────────────────────────────
/// 크기/모서리 반경/내용이 바뀔 때 각지지 않고 "액체처럼" 늘어나며
/// 전환되는 컨테이너. 미니플레이어 ↔ 풀스크린 전환, 가사 카드 확장
/// 등에 사용.
class FluidMorphCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Duration duration;
  final Curve curve;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final Color? backgroundColor;

  const FluidMorphCard({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.duration = GMotion.cardDuration,
    this.curve = GMotion.cardCurve,
    this.padding,
    this.constraints,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      constraints: constraints,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: curve,
        switchOutCurve: curve,
        transitionBuilder: (widget, animation) {
          // Fluid AI 시그니처: scale-up + fade (slide 아님)
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: scale, child: widget),
          );
        },
        child: child,
      ),
    );
  }
}

/// ── 2. Glow 포커스 컨테이너 ────────────────────────────────────
/// 곡의 accentColor(앨범아트 추출색)를 기반으로 은은한 glow를
/// 테두리에 부여. isFocused=false면 blur만 남고 glow는 사라짐 —
/// "지금 무엇에 집중해야 하는가"를 색으로 표현.
class FluidGlowFocus extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final bool isFocused;
  final double borderRadius;
  final Duration duration;

  const FluidGlowFocus({
    super.key,
    required this.child,
    required this.accentColor,
    this.isFocused = true,
    this.borderRadius = 24,
    this.duration = GMotion.cardDuration,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.15),
                  blurRadius: 48,
                  spreadRadius: 4,
                ),
              ]
            : [],
        border: Border.all(
          color: isFocused
              ? accentColor.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}

/// ── 3. 비대칭 레이어 스태킹 ────────────────────────────────────
/// 완전히 분리된 화면이 아니라 살짝 겹쳐진 레이어로 쌓는 배치.
/// 예: 가사 화면에서 현재 라인이 다음 라인 위로 살짝 겹치며 떠 있음.
/// index가 낮을수록(과거/배경) 더 흐리고 뒤로, focusIndex가 선명하고 크게.
class FluidLayerStack extends StatelessWidget {
  final List<Widget> layers;
  final int focusIndex;
  final double overlapOffset;

  const FluidLayerStack({
    super.key,
    required this.layers,
    required this.focusIndex,
    this.overlapOffset = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(layers.length, (i) {
        final distance = (i - focusIndex).abs();
        final isFocus = i == focusIndex;
        final opacity = isFocus ? 1.0 : (0.55 - distance * 0.15).clamp(0.0, 0.55);
        final scale = isFocus ? 1.0 : (1.0 - distance * 0.04).clamp(0.85, 1.0);
        final dy = (i - focusIndex) * overlapOffset;

        return AnimatedPositioned(
          duration: GMotion.cardDuration,
          curve: GMotion.cardCurve,
          top: dy,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: GMotion.cardDuration,
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: isFocus
                  ? layers[i]
                  : ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                      child: layers[i],
                    ),
            ),
          ),
        );
      }),
    );
  }
}

/// ── 4. 마이크로 인터랙션 래퍼 ──────────────────────────────────
/// 탭/전환 시 딱딱한 slide 대신 scale + fade 조합. 앱 전역에서
/// 곡 전환, 탭 전환 등 일관되게 사용해 "Fluid" 톤을 통일.
class FluidTapFade extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const FluidTapFade({super.key, required this.child, this.onTap});

  @override
  State<FluidTapFade> createState() => _FluidTapFadeState();
}

class _FluidTapFadeState extends State<FluidTapFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GMotion.buttonDuration,
    lowerBound: 0.0,
    upperBound: 0.06,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 - _controller.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// ── 5. 카드 눌림 반응 (제스처를 가로채지 않는 순수 시각 피드백) ──────
/// GestureDetector가 아니라 Listener를 써서, 카드를 눌렀을 때 살짝
/// 눌렸다가 떼면 다시 튕기듯 돌아오는 "생동감"만 주고 실제 탭/드래그
/// 제스처(볼륨 슬라이더 드래그 등)는 그대로 안쪽 위젯에 전달됨.
/// "화면이 살아 움직인다"는 Liquid UI 느낌을 어떤 카드에든 안전하게
/// 얹을 수 있는 범용 래퍼.
class FluidPressFeel extends StatefulWidget {
  final Widget child;
  final double pressScale;
  final Duration duration;

  const FluidPressFeel({
    super.key,
    required this.child,
    this.pressScale = 0.97,
    this.duration = GMotion.buttonDuration,
  });

  @override
  State<FluidPressFeel> createState() => _FluidPressFeelState();
}

class _FluidPressFeelState extends State<FluidPressFeel> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressScale : 1.0,
        duration: widget.duration,
        curve: GMotion.buttonCurve,
        child: widget.child,
      ),
    );
  }
}

/// ── 7. 숨쉬는 앰비언트 glow ──────────────────────────────────────
/// 정적인 배경 톤 위에 얹는, 아주 천천히(4~6초 주기) 밝아졌다
/// 어두워지는 큰 radial glow. "화면이 살아있다"는 인상을 주는
/// 가장 저비용 요소 — 곡의 accentColor를 그대로 써서 튀지 않게 은은히.
class FluidBreathingGlow extends StatefulWidget {
  final Color color;
  final Duration period;
  final double minOpacity;
  final double maxOpacity;

  const FluidBreathingGlow({
    super.key,
    required this.color,
    this.period = GMotion.ambientBreathe,
    this.minOpacity = 0.03,
    this.maxOpacity = 0.08,
  });

  @override
  State<FluidBreathingGlow> createState() => _FluidBreathingGlowState();
}

class _FluidBreathingGlowState extends State<FluidBreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant FluidBreathingGlow old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period) {
      _controller.duration = widget.period;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          final opacity = widget.minOpacity + (widget.maxOpacity - widget.minOpacity) * t;
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  widget.color.withValues(alpha: opacity),
                  widget.color.withValues(alpha: 0.0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ── 8. 컨텍스트 적응형 스위처 ──────────────────────────────────
/// "AI가 상황을 판단해 UI를 재구성한다"는 Fluid AI 핵심 철학의
/// 최소 구현. builder가 현재 컨텍스트(예: 가사 유무, 재생 상태)를
/// 받아 어떤 콘텐츠를 카드에 채울지 결정하고, FluidMorphCard가
/// 그 전환을 부드럽게 처리.
///
/// 사용 예:
/// ```dart
/// FluidAdaptiveContent<PlayerContext>(
///   context: currentContext,
///   builder: (ctx) {
///     if (ctx.hasLyrics) return LyricsPreview(key: const ValueKey('lyrics'));
///     return FftVisualizer(key: const ValueKey('fft'));
///   },
/// )
/// ```
class FluidAdaptiveContent<T> extends StatelessWidget {
  final T context;
  final Widget Function(T context) builder;
  final double borderRadius;

  const FluidAdaptiveContent({
    super.key,
    required this.context,
    required this.builder,
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext buildContext) {
    return FluidMorphCard(
      borderRadius: borderRadius,
      child: builder(context),
    );
  }
}