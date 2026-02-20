import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ad_service.dart';

void showPassDialog(BuildContext context, VoidCallback onUpdated) async {
  // 1. 초기 상태 데이터 로드
  bool hasPass = await AdService.isFullAccess();
  DateTime? expiryTime = await AdService.getPassExpiryTime();
  var priceData = await AdService.getPriceInfo();

  if (!context.mounted) return;

  Timer? dialogTimer;

  showDialog(
    context: context,
    barrierDismissible: hasPass, 
    builder: (context) => PopScope(
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
            if (expiryTime == null || !hasPass) return "Expired";
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

          final bool isGoldenTime = priceData['isDiscount'];
          final Color accentColor = isGoldenTime ? Colors.amber : const Color(0xFFD1C4E9);

          // 🔥 광고 버튼에 표시될 텍스트 결정
          String adButtonLabel = "WATCH ADS TO ACTIVATE (0/2)";
          if (AdService.watchedCount == 1) {
            adButtonLabel = "WATCH ONE MORE AD (1/2)";
          } else if (AdService.watchedCount >= 2) {
            adButtonLabel = "READY TO ACTIVATE";
          }

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AlertDialog(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    const SizedBox(height: 25),
                    Text(
                      hasPass ? "PASS ACTIVE" : "ACCESS DENIED",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        getRemainingTime(),
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      hasPass
                          ? "You have full access to all features."
                          : "Free trial expired. Watch 2 ads or\nupgrade to Lifetime Pro to continue.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // 라이프타임 구매 섹션
                    _buildGlassContainer(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isGoldenTime ? Icons.auto_awesome : Icons.stars_rounded,
                                  color: accentColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "LIFETIME PRO",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: isGoldenTime ? Colors.amber : Colors.white,
                                ),
                              ),
                            ],
                          ),
                          if (isGoldenTime) ...[
                            const SizedBox(height: 8),
                            const Text(
                              "🔥 30% INSTALL DISCOUNT",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildActionButton(
                            label: "BUY NOW - ${priceData['price']}",
                            onPressed: () {
                              dialogTimer?.cancel();
                              Navigator.pop(context);
                            },
                            color: accentColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🔥 광고 버튼 (동적 텍스트 적용)
                    _buildActionButton(
                      label: adButtonLabel, 
                      onPressed: () async {
                        try {
                          await AdService.startAdProcess(
                            context,
                            onComplete: () async {
                              // 보상 획득 완료 시 (2회 시청 시)
                              hasPass = await AdService.isFullAccess();
                              expiryTime = await AdService.getPassExpiryTime();
                              onUpdated(); // 부모 화면 갱신
                              
                              if (context.mounted) {
                                Navigator.pop(context); // 2회 완료 시 다이얼로그 닫기
                              }
                            },
                          );
                          // 1회 시청 후 돌아왔을 때 버튼 텍스트(1/2)를 갱신하기 위해 상태 업데이트
                          setDialogState(() {}); 
                        } catch (e) {
                          debugPrint("광고 프로세스 에러: $e");
                        }
                      },
                      color: const Color(0xFF735DA5),
                    ),

                    if (hasPass) ...[
                      const SizedBox(height: 15),
                      GestureDetector(
                        onTap: () {
                          dialogTimer?.cancel();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "CLOSE",
                          style: TextStyle(
                            color: Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  ).then((_) {
    dialogTimer?.cancel();
  });
}

// ... _buildGlassContainer 및 _buildActionButton 함수는 기존과 동일 ...

// --- 공통 글래스모피즘 위젯 ---

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
}) {
  return GestureDetector(
    onTap: onPressed,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
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
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontSize: 13,
        ),
      ),
    ),
  );
}
