import 'dart:ui';
import 'package:flutter/material.dart';

void showCreatorDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final bool isLandscape = size.width > size.height;
  
  // 요즘 감성의 화이트/퍼플 글래스 팔레트
  const Color accentColor = Color(0xFFD1C4E9); // 연한 보라 (유리 위에서 잘 보임)
  
  showDialog(
    context: context,
    builder: (context) => BackdropFilter(
      // [핵심] 다이얼로그 뒤쪽 배경을 블러 처리하여 깊이감 형성
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.1), // 투명한 배경
        surfaceTintColor: Colors.transparent,
        // 테두리에 얇은 빛(Border)을 주어 유리의 두께감 표현
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: isLandscape ? size.width * 0.7 : size.width * 0.85,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. 상단 로고 배지 (Glass Badge)
                _buildGlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Text(
                    "GLASNYL",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "ZN LABS",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 30),

                // 2. 가로/세로 대응 카드 섹션
                isLandscape
                    ? Row(
                        children: [
                          Expanded(child: _buildCreatorCard("Jaewon Jo", "Main Dev", accentColor)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildCreatorCard("Minchan Kim", "Special Thanks", accentColor)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildCreatorCard("Myungwan Jeong", "Special Thanks", accentColor)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildCreatorRow("Jaewon Jo", "Main Developer", accentColor),
                          const SizedBox(height: 12),
                          _buildCreatorRow("Minchan Kim", "Special Thanks To", accentColor),
                          const SizedBox(height: 12),
                          _buildCreatorRow("Myungwan Jeong", "Special Thanks To", accentColor),
                        ],
                      ),

                const SizedBox(height: 40),
                Text(
                  "\"Music, Visualized.\"",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 30),

                // 3. 닫기 버튼
                _buildGlassButton(context, "CLOSE", accentColor),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// --- 글래스모피즘 전용 위젯 빌더 ---

// 1. 공통 유리 컨테이너
Widget _buildGlassContainer({required Widget child, EdgeInsets? padding, double borderRadius = 20}) {
  return Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
    ),
    child: child,
  );
}

// 2. 가로형 카드
Widget _buildCreatorCard(String name, String role, Color accent) {
  return _buildGlassContainer(
    child: Column(
      children: [
        Icon(Icons.auto_awesome, size: 24, color: accent),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(role, style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      ],
    ),
  );
}

// 3. 세로형 로우
Widget _buildCreatorRow(String name, String role, Color accent) {
  return _buildGlassContainer(
    child: Row(
      children: [
        Icon(Icons.auto_awesome, size: 20, color: accent),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
            Text(role, style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    ),
  );
}

// 4. 유리 버튼
Widget _buildGlassButton(BuildContext context, String label, Color accent) {
  return GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.3), accent.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
      ),
    ),
  );
}