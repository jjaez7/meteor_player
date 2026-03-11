import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ad_service.dart';

void showPassDialog(BuildContext context, VoidCallback onUpdated) async {
  bool hasPass = await AdService.isFullAccess();
  DateTime? expiryTime = await AdService.getPassExpiryTime();

  if (!context.mounted) return;

  Timer? dialogTimer;

  showDialog(
    context: context,
    barrierDismissible: hasPass,
    builder: (dialogCtx) => PopScope(
      canPop: hasPass,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          dialogTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (context.mounted) {
              setDialogState(() {});
            } else {
              t.cancel();
            }
          });

          String getRemainingTime() {
            if (!hasPass) return "Expired";
            final duration = expiryTime!.difference(DateTime.now());
            if (duration.isNegative) return "Expired";
            final hours = duration.inHours;
            final minutes = duration.inMinutes.remainder(60);
            final seconds = duration.inSeconds.remainder(60);
            if (hours > 0) {
              return "${hours}h ${minutes}m ${seconds.toString().padLeft(2, '0')}s left";
            }
            return "${minutes}m ${seconds.toString().padLeft(2, '0')}s left";
          }

          const Color accentColor = Color(0xFFD1C4E9);

          String adButtonLabel = "WATCH ADS TO ACTIVATE (0/2)";
          if (AdService.watchedCount == 1) {
            adButtonLabel = "WATCH ONE MORE AD (1/2)";
          } else if (AdService.watchedCount >= 2) {
            adButtonLabel = "READY TO ACTIVATE";
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final mq = MediaQuery.of(context);
              final screenW = mq.size.width;
              final screenH = mq.size.height;
              final isLandscape = screenW > screenH;

              final dialogMaxW =
                  (screenW * (isLandscape ? 0.55 : 0.88)).clamp(280.0, 480.0);
              final dialogMaxH =
                  (screenH * (isLandscape ? 0.92 : 0.88)).clamp(0.0, 740.0);

              final gap = (screenH * 0.018).clamp(6.0, 20.0);
              final gapLg = (screenH * 0.030).clamp(10.0, 30.0);

              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: dialogMaxW,
                        maxHeight: dialogMaxH,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: (screenW * 0.05).clamp(16.0, 28.0),
                              vertical: (screenH * 0.025).clamp(14.0, 28.0),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── GLASNYL PASS 뱃지
                                _buildGlassContainer(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: const Text(
                                    "GLASNYL PASS",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                ),
                                SizedBox(height: gapLg),

                                // ── 상태 타이틀
                                Text(
                                  hasPass ? "PASS ACTIVE" : "ACCESS DENIED",
                                  style: TextStyle(
                                    fontSize:
                                        (screenW * 0.055).clamp(16.0, 26.0),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: gap),

                                // ── 남은 시간 뱃지
                                if (hasPass && expiryTime != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: accentColor
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      getRemainingTime(),
                                      style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: (screenW * 0.035)
                                            .clamp(11.0, 16.0),
                                      ),
                                    ),
                                  ),
                                SizedBox(height: gap),

                                // ── 설명 텍스트
                                Text(
                                  hasPass
                                      ? "You have full access to all features."
                                      : "Free trial expired.\nWatch 2 ads to continue.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize:
                                        (screenW * 0.032).clamp(11.0, 15.0),
                                    height: 1.5,
                                  ),
                                ),
                                SizedBox(height: gapLg),

                                // ── 광고 시청 버튼
                                if (!hasPass) _buildActionButton(
                                  label: adButtonLabel,
                                  onPressed: () async {
                                    try {
                                      await AdService.startAdProcess(
                                        context,
                                        onComplete: () async {
                                          hasPass =
                                              await AdService.isFullAccess();
                                          expiryTime = await AdService
                                              .getPassExpiryTime();
                                          onUpdated();
                                          if (context.mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                      );
                                      setDialogState(() {});
                                    } catch (e) {
                                      debugPrint("광고 프로세스 에러: $e");
                                    }
                                  },
                                  color: const Color(0xFF735DA5),
                                  fontSize:
                                      (screenW * 0.032).clamp(11.0, 14.0),
                                ),

                                // ── CLOSE (패스 보유 시만 표시)
                                if (hasPass) ...[
                                  SizedBox(height: gap),
                                  GestureDetector(
                                    onTap: () {
                                      dialogTimer?.cancel();
                                      Navigator.of(context).pop();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Text(
                                        "CLOSE",
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontWeight: FontWeight.bold,
                                          fontSize: (screenW * 0.030)
                                              .clamp(10.0, 13.0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  ).then((_) {
    dialogTimer?.cancel();
  });
}

// ─────────────────────────────────────
// 공통 글래스모피즘 위젯
// ─────────────────────────────────────

Widget _buildGlassContainer({required Widget child, EdgeInsets? padding}) {
  return Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: child,
  );
}

Widget _buildActionButton({
  required String label,
  required VoidCallback onPressed,
  required Color color,
  double fontSize = 13,
}) {
  return GestureDetector(
    onTap: onPressed,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontSize: fontSize,
        ),
      ),
    ),
  );
}