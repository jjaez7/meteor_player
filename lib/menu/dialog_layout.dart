import 'dart:ui';
import 'package:flutter/material.dart';

void showLayoutDialog({
  required BuildContext context,
  required bool isEditMode,
  required Function(bool) onEditModeChanged,
  required Color playBtnColor,
  required VoidCallback onResetLayout,
}) {
  // 글래스 테마용 투명 화이트/텍스트 컬러 정의
  final Color glassTextColor = Colors.white;
  final Color glassSubTextColor = Colors.white.withValues(alpha: 0.6);

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) => Container(),
    transitionBuilder: (context, anim1, anim2, child) {
      return Transform.scale(
        scale: Curves.easeOutBack.transform(anim1.value),
        child: Opacity(
          opacity: anim1.value,
          child: BackdropFilter(
            // [1] 배경 블러 처리
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AlertDialog(
              backgroundColor: Colors.white.withValues(alpha: 0.1), // 반투명 유리 배경
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5), // 유리 테두리
              ),
              title: Text(
                "LAYOUT EDIT",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.2,
                  color: glassTextColor,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  // 편집 모드 스위치 타일
                  _buildGlassTile(
                    "Enable Edit Mode",
                    Switch(
                      value: isEditMode,
                      activeThumbColor: playBtnColor,
                      activeTrackColor: playBtnColor.withValues(alpha: 0.3),
                      inactiveThumbColor: Colors.white60,
                      onChanged: (v) {
                        onEditModeChanged(v);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 위치 초기화 타일
                  _buildGlassTile(
                    "Reset Positions",
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.orangeAccent),
                      onPressed: () {
                        onResetLayout();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 가이드 텍스트 (소프트 레이어 안쪽)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "In edit mode, you can drag components\nto customize your own player layout.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: glassSubTextColor, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 닫기 버튼
                  _buildGlassButton(context, "DONE", glassTextColor),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

// --- 글래스모피즘 전용 서브 위젯 ---

// 1. 리스트 타일용 유리 컨테이너
Widget _buildGlassTile(String title, Widget trailing) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05), // 극소량의 화이트로 면 분할
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        trailing,
      ],
    ),
  );
}

// 2. 하단 확인 버튼
Widget _buildGlassButton(BuildContext context, String label, Color textColor) {
  return GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: textColor,
        ),
      ),
    ),
  );
}