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
                colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44), Color(0xFF1E1E2E)],
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
                title: "Welcome",
                subtitle: "Nice to meet you!",
                description: "Thank you for choosing Meteor. Let us take you on a journey through the perfect blend of sound and vision.",
                icon: Icons.auto_awesome_rounded,
                isLandscape: isLandscape,
              ),
              _buildGlassPage(
                index: 1,
                title: "Meteor Player",
                subtitle: "The Aesthetics of Rotation",
                description: "Experience the nostalgia of analog vinyl in the digital streaming era. Meteor Player redefines music as a visual masterpiece.",
                icon: Icons.album_rounded,
                isLandscape: isLandscape,
              ),
              _buildGlassPage(
                index: 2,
                title: "Visual Fidelity",
                subtitle: "Needle & Vinyl Interface",
                description: "Synchronized tonearm movements and smooth rotation animations evoke the tactile pleasure of high-end audio equipment.",
                icon: Icons.settings_input_component_rounded,
                isLandscape: isLandscape,
              ),
              _buildGlassPage(
                index: 3,
                title: "Seamless Sync",
                subtitle: "Android MediaSession Integration",
                description: "Low-latency metadata streaming from YouTube, Spotify, and more via Native Platform Channels.",
                icon: Icons.shutter_speed_rounded,
                isLandscape: isLandscape,
              ),
              _buildGlassPage(
                index: 4,
                title: "Get Started",
                subtitle: "Your Music, Our Vision",
                description: "Connect your favorite player and watch your music come to life with our color-adaptive UI engine.",
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
                      // 🚀 1. 미디어 권한 요청 (시스템 팝업 실행)
                      if (Platform.isAndroid) {
                        try {
                          // 오디오 권한과 저장소 권한을 동시에 요청
                          await [
                            Permission.audio,
                            Permission.storage,
                          ].request();
                        } catch (e) {
                          debugPrint("Permission request error: $e");
                        }
                      }

                      // 🚀 2. 첫 실행 완료 플래그 저장
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isFirstRun', false);

                      // 🚀 3. 메인 화면으로 이동
                      if (!mounted) return;
                      Navigator.pushReplacementNamed(context, '/main');
                    } else {
                      // 다음 온보딩 페이지로 이동
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
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 600),
        opacity: _currentPage == index ? 1.0 : 0.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: isLandscape ? MediaQuery.of(context).size.width * 0.8 : MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
              ),
              child: isLandscape 
                ? Row(
                    children: [
                      _buildIconContainer(icon, size: 120),
                      const SizedBox(width: 40),
                      Expanded(child: _buildTextContent(title, subtitle, description)),
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
          style: TextStyle(fontSize: 13, letterSpacing: 4, fontWeight: FontWeight.bold, color: accentColor),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
        ),
        const SizedBox(height: 20),
        Text(
          description,
          style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.6), height: 1.6),
        ),
      ],
    );
  }

  Widget _buildGlassActionButton(String label, VoidCallback onTap) {
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2),
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
            color: _currentPage == index ? accentColor : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  Widget _buildBlurOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}