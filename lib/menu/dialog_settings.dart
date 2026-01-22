import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

void showSettingsDialog({
  required BuildContext context,
  required Color bgColor,
  required Color lpColor,
  required Color textColor,
  required Color artistColor,
  required Color barColor,
  required Color playBtnColor,
  required Function(Color, String) onColorChanged,
  required VoidCallback onResetColors, // 이름 변경: onReset -> onResetColors
}) {
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
          child: AlertDialog(
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            title: Text(
              "THEME SETTINGS",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: textColor,
                letterSpacing: 1.5,
              ),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 15,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      _neoColorCircle(
                        context,
                        "BG",
                        bgColor,
                        bgColor,
                        textColor,
                        (c) => onColorChanged(c, "bg"),
                      ),
                      _neoColorCircle(
                        context,
                        "LP",
                        lpColor,
                        bgColor,
                        textColor,
                        (c) => onColorChanged(c, "lp"),
                      ),
                      _neoColorCircle(
                        context,
                        "TEXT",
                        textColor,
                        bgColor,
                        textColor,
                        (c) => onColorChanged(c, "text"),
                      ),
                      _neoColorCircle(
                        context,
                        "SUB",
                        artistColor,
                        bgColor,
                        textColor,
                        (c) => onColorChanged(c, "artist"),
                      ),
                      _neoColorCircle(
                        context,
                        "BAR",
                        barColor,
                        bgColor,
                        textColor,
                        (c) => onColorChanged(c, "bar"),
                      ),
                      _neoColorCircle(
                        context,
                        "BTN",
                        playBtnColor,
                        bgColor,
                        textColor,
                        (c) => onColorChanged(c, "btn"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          "RESET COLOR",
                          bgColor,
                          Colors.redAccent,
                          () {
                            onResetColors();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildActionButton(
                          "DONE",
                          bgColor,
                          textColor,
                          () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

// --- 누락되었던 헬퍼 위젯들 ---

Widget _neoColorCircle(
  BuildContext context,
  String label,
  Color color,
  Color bgColor,
  Color textColor,
  Function(Color) onSelect,
) {
  return Column(
    children: [
      GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              title: const Text(
                "PICK A COLOR",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: color,
                  onColorChanged: onSelect,
                  pickerAreaHeightPercent: 0.7,
                  enableAlpha: false,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("DONE"),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: bgColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                offset: const Offset(3, 3),
                blurRadius: 5,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor.withValues(alpha: 0.6),
        ),
      ),
    ],
  );
}

Widget _buildActionButton(
  String label,
  Color bgColor,
  Color color,
  VoidCallback onTap,
) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-4, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: color,
          fontSize: 12,
        ),
      ),
    ),
  );
}
