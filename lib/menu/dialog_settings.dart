import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../theme/glass_material.dart';
import '../theme/design_tokens.dart';

void showSettingsDialog({
  required BuildContext context,
  required Color bgColor,
  required Color lpColor,
  required Color textColor,
  required Color artistColor,
  required Color barColor,
  required Color playBtnColor,
  required Function(Color, String) onColorChanged,
  required VoidCallback onResetColors,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    // Popup motion 토큰: 오버슈트/바운스 없이 scale+fade로 차분하게
    transitionDuration: GMotion.popupDuration,
    pageBuilder: (context, anim1, anim2) => GlassPopupShell(
      accentColor: playBtnColor,
      maxWidth: 420,
      child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                "THEME SETTINGS",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
                const SizedBox(height: 20),
                    // [소프트 레이어] 컬러 칩들이 담긴 반투명 박스
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(GRadius.largeCard),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 25,
                        alignment: WrapAlignment.center,
                        children: [
                          _glassColorCircle(context, "BG", bgColor, (c) => onColorChanged(c, "bg")),
                          _glassColorCircle(context, "LP", lpColor, (c) => onColorChanged(c, "lp")),
                          _glassColorCircle(context, "TEXT", textColor, (c) => onColorChanged(c, "text")),
                          _glassColorCircle(context, "SUB", artistColor, (c) => onColorChanged(c, "artist")),
                          _glassColorCircle(context, "BAR", barColor, (c) => onColorChanged(c, "bar")),
                          _glassColorCircle(context, "BTN", playBtnColor, (c) => onColorChanged(c, "btn")),
                        ],
                      ),
                    ),
                    const SizedBox(height: 35),
                    Row(
                      children: [
                        Expanded(
                          child: _glassActionButton(
                            "RESET",
                            Colors.redAccent.withValues(alpha: 0.8),
                            onResetColors,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _glassActionButton(
                            "DONE",
                            Colors.white.withValues(alpha: 0.2),
                            () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
              ],
      ),
    ),
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(opacity: anim1, child: child);
    },
  );
}

// --- 글래스 전용 헬퍼 위젯 ---

Widget _glassColorCircle(
  BuildContext context,
  String label,
  Color color,
  Function(Color) onSelect,
) {
  return Column(
    children: [
      GestureDetector(
        onTap: () {
          // 컬러 피커도 글래스모피즘 스타일로 띄움
          showDialog(
            context: context,
            builder: (context) => GlassPopupShell(
              accentColor: color,
              maxWidth: 340,
              padding: const EdgeInsets.all(GSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("PICK $label COLOR",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: GSpace.md),
                  SingleChildScrollView(
                    child: ColorPicker(
                      pickerColor: color,
                      onColorChanged: onSelect,
                      pickerAreaHeightPercent: 0.7,
                      enableAlpha: false,
                      displayThumbColor: true,
                    ),
                  ),
                  const SizedBox(height: GSpace.md),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("DONE", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        },
        child: Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: 0.7),
          letterSpacing: 1.0,
        ),
      ),
    ],
  );
}

Widget _glassActionButton(String label, Color color, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(GRadius.mediumCard),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          if (label == "RESET")
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.5,
          fontSize: 13,
        ),
      ),
    ),
  );
}