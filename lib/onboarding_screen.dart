import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool isLastPage = false;

  // Glassmorphism Palette
  final Color accentColor = const Color(0xFFD1C4E9); // 소프트 퍼플
  final Color glassBaseColor = Colors.white.withValues(alpha: 0.1);

  @override
  void dispose() {
    _controller.dispose(); // PageController 메모리 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isLandscape = size.width > size.height;

    return Scaffold(
      body: Stack(
        children: [
          // [1] 배경: 부드러운 그라데이션 레이어
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1E2E),
                  Color(0xFF2D2D44),
                  Color(0xFF1E1E2E),
                ],
              ),
            ),
          ),

          // 장식용 빛의 구체 (소프트 레이어 느낌 극대화)
          Positioned(
            top: -50,
            right: -50,
            child: _buildBlurOrb(200, accentColor.withValues(alpha: 0.2)),
          ),

          // [2] 메인 콘텐츠 (PageView)
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                isLastPage = index == 4;
              });
            },
            children: [
              _buildGlassPage(
                index: 0,
                title: "Welcome to GLASNYL",
                subtitle: "The Next Era of Music Visuals",
                description:
                    "Thank you for choosing GLASNYL OS. Step into a world where glassmorphism aesthetics meets high-fidelity audio engineering.",
                icon: Icons.auto_awesome_rounded,
                isLandscape: isLandscape,
              ),
              _buildGlassPage(
                index: 1,
                title: "Interactive Vinyl",
                subtitle: "More than just a Rotation",
                description:
                    "Tap once for lyrics, twice for artwork, and long-press to refresh. Our Hifi engine synchronizes rotation with your core audio stream.",
                icon: Icons.album_rounded,
                isLandscape: isLandscape,
              ),
              _buildGlassPage(
                index: 2,
                title: "Complete Control",
                subtitle: "Precision at Your Fingertips",
                description:
                    "Drag the progress bar to seek your favorite moments. Access PiP mode and Screen Lock via the left-side drop-down menu.",
                icon: Icons.settings_input_component_rounded,
                isLandscape: isLandscape,
              ),
              _buildGlassPage(
                index: 3,
                title: "Aesthetic Precision", // 또는 "Personalized Canvas"
                subtitle: "Design Your Own Space",
                description:
                    "Beyond a fixed interface. Enter our advanced calibration mode to freely reposition and resize UI modules, crafting your own unique glassmorphic workspace.",
                icon: Icons
                    .dashboard_customize_rounded, // 아이콘도 더 적절한 커스터마이즈 아이콘으로 추천
                isLandscape: isLandscape,
              ),
              _buildGlassPage(
                index: 4,
                title: "Get Started",
                subtitle: "Ignite Your Senses",
                description:
                    "Experience our color-adaptive UI that breathes with your music. Let the journey begin.",
                icon: Icons.rocket_launch_rounded,
                isLandscape: isLandscape,
              ),
            ],
          ),

          // [3] 하단 네비게이션 (인디케이터 & 버튼)
          Positioned(
            bottom: isLandscape ? 30 : 60,
            left: 30,
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircularIndicator(5),
                _buildGlassActionButton(
                  isLastPage ? "START!" : "NEXT",
                  () async {
                    if (isLastPage) {
                      if (Platform.isAndroid) {
                        // 권한 요청 결과를 Map으로 받아서 처리 (return 생략 방지)
                        Map<Permission, PermissionStatus> statuses = await [
                          Permission.audio,
                          Permission.storage,
                          // 안드로이드 13 이상을 위해 아래 권한 추가를 권장합니다.
                          // Permission.nearbyWifiDevices,
                        ].request();

                        debugPrint("Permissions: $statuses");
                      }

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isFirstRun', false);

                      if (!mounted) return;
                      Navigator.pushReplacementNamed(context, '/main');
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutQuart,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildGlassPage({
    required int index,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required bool isLandscape,
  }) {
    return Center(
      child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: isLandscape
                  ? MediaQuery.of(context).size.width * 0.8
                  : MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: isLandscape
                  ? Row(
                      children: [
                        _buildIconContainer(icon, size: 120),
                        const SizedBox(width: 40),
                        Expanded(
                          child: _buildTextContent(
                            title,
                            subtitle,
                            description,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildIconContainer(icon),
                        const SizedBox(height: 40),
                        _buildTextContent(title, subtitle, description),
                      ],
                    ),
            ),
          ),
        ),
    );
  }

  Widget _buildIconContainer(IconData icon, {double size = 140}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, size: size * 0.4, color: Colors.white),
    );
  }

  Widget _buildTextContent(String title, String subtitle, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 4,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          description,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassActionButton(String label, Function() onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accentColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularIndicator(int count) {
    return Row(
      children: List.generate(count, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 6,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? accentColor
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  Widget _buildBlurOrb(double size, Color color) {
    // BackdropFilter 제거: 단색 배경을 블러해도 시각 효과 없음, 연산만 낭비
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 60, spreadRadius: 20),
        ],
      ),
    );
  }
}