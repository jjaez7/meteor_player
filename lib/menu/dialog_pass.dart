import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../services/ad_service.dart';
import '../services/purchase_service.dart';

void showPassDialog(BuildContext context, VoidCallback onUpdated) async {
  bool hasPass = await AdService.isFullAccess();
  DateTime? expiryTime = await AdService.getPassExpiryTime();
  var priceData = await AdService.getPriceInfo();

  if (!context.mounted) return;

  Timer? dialogTimer;

  showDialog(
    context: context,
    barrierDismissible: hasPass,
    builder: (dialogCtx) => PopScope(
      canPop: hasPass,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          // Lifetime Pro는 카운트다운 불필요 → 타이머 생략
          if (!(hasPass && expiryTime == null)) {
            dialogTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (context.mounted) {
                setDialogState(() {});
              } else {
                t.cancel();
              }
            });
          }

          // ── 결제 콜백 등록
          PurchaseService.onPurchaseSuccess = () async {
            hasPass = await AdService.isFullAccess();
            expiryTime = await AdService.getPassExpiryTime();
            onUpdated();
            if (context.mounted) {
              setDialogState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 Lifetime Pro가 활성화되었습니다!'),
                  duration: Duration(seconds: 3),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
              dialogTimer?.cancel();
              Navigator.of(context).pop();
            }
          };

          PurchaseService.onPurchaseRestored = () async {
            hasPass = await AdService.isFullAccess();
            expiryTime = await AdService.getPassExpiryTime();
            onUpdated();
            if (context.mounted) {
              setDialogState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ 구매 내역이 복원되었습니다.'),
                  duration: Duration(seconds: 3),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
              dialogTimer?.cancel();
              Navigator.of(context).pop();
            }
          };

          PurchaseService.onPurchaseError = (message) {
            if (context.mounted) {
              setDialogState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  duration: const Duration(seconds: 3),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          };

          // ✅ 추가: isBuying 상태 변경 시 다이얼로그 즉시 리빌드
          PurchaseService.onBuyingStateChanged = () {
            if (context.mounted) setDialogState(() {});
          };

          // expiryTime == null + hasPass == true → Lifetime Pro 상태
          final bool isLifetime = hasPass && expiryTime == null;

          String getRemainingTime() {
            if (!hasPass) return "Expired";
            if (isLifetime) return "LIFETIME ∞";
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
          // Lifetime Pro이면 항상 골드 강조
          final Color accentColor = isLifetime
              ? Colors.amber
              : (isGoldenTime ? Colors.amber : const Color(0xFFD1C4E9));

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
                                      : "Free trial expired. Watch 2 ads or\nupgrade to Lifetime Pro to continue.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize:
                                        (screenW * 0.032).clamp(11.0, 15.0),
                                    height: 1.5,
                                  ),
                                ),
                                SizedBox(height: gapLg),

                                // ── 라이프타임 구매 섹션 (이미 구매한 경우 숨김)
                                if (!isLifetime) _buildGlassContainer(
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isGoldenTime
                                                ? Icons.auto_awesome
                                                : Icons.stars_rounded,
                                            color: accentColor,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "LIFETIME PRO",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: isGoldenTime
                                                  ? Colors.amber
                                                  : Colors.white,
                                              fontSize: (screenW * 0.035)
                                                  .clamp(12.0, 16.0),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isGoldenTime) ...[
                                        SizedBox(height: gap * 0.5),
                                        const Text(
                                          "🔥 30% INSTALL DISCOUNT",
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                      SizedBox(height: gap),

                                      // ── BUY NOW 버튼 ─ 실제 결제 호출
                                      PurchaseService.isBuying
                                          ? const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 14),
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.5,
                                                ),
                                              ),
                                            )
                                          : _buildActionButton(
                                              label:
                                                  "BUY NOW - ${priceData['price']}",
                                              onPressed: () async {
                                                setDialogState(() {}); // 로딩 시작 표시
                                                await PurchaseService
                                                    .buyLifetimePro(isDiscount: isGoldenTime);

                                                // ✅ 추가: 스트림 이벤트가 오지 않을 경우
                                                // 5초 후 강제로 로딩 스피너 해제 (안전장치)
                                                Future.delayed(
                                                  const Duration(seconds: 5),
                                                  () {
                                                    if (context.mounted &&
                                                        PurchaseService.isBuying) {
                                                      PurchaseService.forceResetBuying();
                                                    }
                                                  },
                                                );

                                                if (context.mounted) {
                                                  setDialogState(() {});
                                                }
                                              },
                                              color: accentColor,
                                              fontSize: (screenW * 0.032)
                                                  .clamp(11.0, 14.0),
                                            ),

                                      SizedBox(height: gap * 0.6),

                                      // ── RESTORE PURCHASE (App Store 심사 필수 요건)
                                      GestureDetector(
                                        onTap: () async {
                                          await PurchaseService
                                              .restorePurchases();
                                          // 결과는 onPurchaseRestored 콜백으로 처리
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: Text(
                                            "RESTORE PURCHASE",
                                            style: TextStyle(
                                              color: accentColor
                                                  .withValues(alpha: 0.65),
                                              fontWeight: FontWeight.bold,
                                              fontSize: (screenW * 0.028)
                                                  .clamp(10.0, 12.0),
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: accentColor
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isLifetime) SizedBox(height: gap),

                                // ── 광고 시청 버튼 (이미 구매한 경우 숨김)
                                if (!isLifetime) _buildActionButton(
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

                                // ── [DEBUG ONLY] 결제 리셋 버튼 — release 빌드에서 자동 제거
                                if (kDebugMode) ...[
                                  SizedBox(height: gap),
                                  GestureDetector(
                                    onTap: () async {
                                      await PurchaseService.debugResetPurchase();
                                      hasPass = await AdService.isFullAccess();
                                      expiryTime = await AdService.getPassExpiryTime();
                                      onUpdated();
                                      if (context.mounted) {
                                        setDialogState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('🧪 [DEBUG] 결제 상태 초기화됨'),
                                            duration: Duration(seconds: 2),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Text(
                                        "🧪 DEBUG: RESET PURCHASE",
                                        style: TextStyle(
                                          color: Colors.orange.withValues(alpha: 0.7),
                                          fontWeight: FontWeight.bold,
                                          fontSize: (screenW * 0.026).clamp(9.0, 12.0),
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
    // 다이얼로그 닫힐 때 콜백 정리 (메모리 누수 방지)
    PurchaseService.onPurchaseSuccess = null;
    PurchaseService.onPurchaseRestored = null;
    PurchaseService.onPurchaseError = null;
    PurchaseService.onBuyingStateChanged = null; // ✅ 추가

    // ✅ 추가: 다이얼로그 닫힐 때 혹시 남아있는 로딩 상태 강제 초기화
    if (PurchaseService.isBuying) {
      PurchaseService.forceResetBuying();
    }
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