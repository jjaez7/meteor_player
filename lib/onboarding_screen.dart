import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'theme/design_tokens.dart';

// ── 페이지 데이터 ──────────────────────────────────────────────
class _PageData {
  final String tag;
  final String headline;
  final String body;
  final IconData icon;
  final Color accent;

  const _PageData({
    required this.tag,
    required this.headline,
    required this.body,
    required this.icon,
    required this.accent,
  });
}

const List<_PageData> _pages = [
  _PageData(
    tag: "GLASNYL  ·  WELCOME",
    headline: "See\nthe\nMusic.",
    body: "A glassmorphic vinyl player built around your music. Not just a player — a visual experience.",
    icon: Icons.auto_awesome_rounded,
    accent: Color(0xFFD1C4E9),
  ),
  _PageData(
    tag: "01  ·  VINYL ENGINE",
    headline: "Spin,\nTap,\nFeel.",
    body: "Tap for lyrics. Double-tap for artwork. Long-press to sync. The vinyl reacts to every beat.",
    icon: Icons.album_rounded,
    accent: Color(0xFFB39DDB),
  ),
  _PageData(
    tag: "02  ·  CONTROLS",
    headline: "Every\nDetail\nYours.",
    body: "Seek with precision. PiP mode, screen lock, and full playback control — all one gesture away.",
    icon: Icons.tune_rounded,
    accent: Color(0xFF9FA8DA),
  ),
  _PageData(
    tag: "03  ·  CUSTOMIZE",
    headline: "Build\nYour\nCanvas.",
    body: "Drag and resize every UI element. Your layout, your rules. No two setups are alike.",
    icon: Icons.dashboard_customize_rounded,
    accent: Color(0xFFCE93D8),
  ),
  _PageData(
    tag: "04  ·  ADAPTIVE",
    headline: "Colors\nthat\nBreathe.",
    body: "The interface extracts your album art palette and repaints itself. Every song looks different.",
    icon: Icons.palette_rounded,
    accent: Color(0xFF80CBC4),
  ),
  _PageData(
    tag: "BETA  ·  single-person development",
    headline: "SEE\nTHE\nMUSIC",
    body: "It's a beta I make by myself. It can be buggy.\nPlease feel free to let me know if you have any inconvenience — I'll fix it quickly.",
    icon: Icons.favorite_rounded,
    accent: Color(0xFFD1C4E9),
  ),
];

// ── 메인 위젯 ─────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentPage = 0;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: GMotion.cardDuration,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: GMotion.cardCurve);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    _fadeCtrl.forward(from: 0);
    setState(() => _currentPage = index);
  }

  Future<void> _handleNext() async {
    final isLast = _currentPage == _pages.length - 1;
    if (isLast) {
      if (Platform.isAndroid) {
        await [Permission.audio, Permission.storage].request();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstRun', false);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E18),
      body: Stack(
        children: [
          // ── 배경: 페이지 accent색으로 물드는 radial glow ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.6, -0.7),
                radius: 1.2,
                colors: [
                  page.accent.withValues(alpha: 0.12),
                  const Color(0xFF0E0E18),
                ],
              ),
            ),
          ),

          // ── 우하단 보조 글로우 ──
          Positioned(
            bottom: -80,
            right: -80,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: page.accent.withValues(alpha: 0.08),
                    blurRadius: 120,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          // ── PageView ──
          PageView.builder(
            controller: _controller,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (context, index) => _OnboardingPage(
              data: _pages[index],
              fadeAnim: _fadeAnim,
            ),
          ),

          // ── 하단 네비게이션 ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomNav(
              currentPage: _currentPage,
              total: _pages.length,
              accent: page.accent,
              isLast: isLast,
              onNext: _handleNext,
              onSkip: isLast
                  ? null
                  : () => _controller.animateToPage(
                        _pages.length - 1,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOutCubic,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 개별 페이지 ───────────────────────────────────────────────
class _OnboardingPage extends StatelessWidget {
  final _PageData data;
  final Animation<double> fadeAnim;

  const _OnboardingPage({required this.data, required this.fadeAnim});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return FadeTransition(
      opacity: fadeAnim,
      child: Padding(
        padding: EdgeInsets.only(
          top: topPad + 24,
          left: 36,
          right: 36,
          bottom: 140,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 태그
            Text(
              data.tag,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: data.accent.withValues(alpha: 0.7),
                letterSpacing: 2.5,
              ),
            ),

            const Spacer(flex: 2),

            // 아이콘
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: data.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(GRadius.mediumCard),
                border: Border.all(
                  color: data.accent.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Icon(data.icon, color: data.accent, size: 32),
            ),

            const SizedBox(height: 32),

            // 헤드라인
            Text(
              data.headline,
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.0,
                letterSpacing: -1.5,
              ),
            ),

            const SizedBox(height: 28),

            // 구분선
            Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                color: data.accent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),

            const SizedBox(height: 28),

            // 본문
            Text(
              data.body,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.7,
                letterSpacing: 0.1,
                fontWeight: FontWeight.w400,
              ),
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

// ── 하단 네비게이션 바 ────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentPage;
  final int total;
  final Color accent;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  const _BottomNav({
    required this.currentPage,
    required this.total,
    required this.accent,
    required this.isLast,
    required this.onNext,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(36, 20, 36, 20 + bottomPad),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E18).withValues(alpha: 0.6),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // 도트 인디케이터
              Row(
                children: List.generate(total, (i) {
                  final isActive = i == currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.only(right: 6),
                    width: isActive ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? accent
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),

              const Spacer(),

              // SKIP 버튼
              if (onSkip != null) ...[
                GestureDetector(
                  onTap: onSkip,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "SKIP",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.3),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ],

              // NEXT / START 버튼
              GestureDetector(
                onTap: onNext,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isLast ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isLast
                          ? Colors.transparent
                          : accent.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLast ? "START" : "NEXT",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isLast
                              ? const Color(0xFF0E0E18)
                              : Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 16,
                        color: isLast
                            ? const Color(0xFF0E0E18)
                            : Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}