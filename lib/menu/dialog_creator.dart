import 'dart:ui';
import 'package:flutter/material.dart';

void showCreatorDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final bool isLandscape = size.width > size.height;
  
  // 요즘 감성의 화이트/퍼플 글래스 팔레트
  const Color accentColor = Color(0xFFD1C4E9); // 연한 보라
  
  // 베타 테스터 명단 (12명 예시 이름)
  final List<String> betaTesters = [
    "Jaewon Jo", "Myungwan Jeong", "Jonghyun Yang", "Siwon Park",
"Sieun Park", "Hayoon Kim", "Junho Lee", "Seoyeon Choi",
"Lucas Bennett", "Sofia Marchetti", "Ethan Clarke", "Yuki Tanaka"
  ];

  showDialog(
    context: context,
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
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
                // 1. 상단 로고 배지
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

                // 2. 가로/세로 대응 제작자 카드 섹션
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

                const SizedBox(height: 35),

                // --- 베타 테스터 섹션 추가 ---
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.white24, endIndent: 10)),
                    Text(
                      "BETA TESTERS",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: accentColor.withValues(alpha: 0.8),
                        letterSpacing: 2,
                      ),
                    ),
                    const Expanded(child: Divider(color: Colors.white24, indent: 10)),
                  ],
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: betaTesters.map((name) => _buildTesterChip(name)).toList(),
                ),
                // --------------------------

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

// 베타 테스터용 미니 유리 칩
Widget _buildTesterChip(String name) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Text(
      name,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Colors.white70,
      ),
    ),
  );
}

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