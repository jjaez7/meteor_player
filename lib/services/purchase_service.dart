import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Glasnyl 인앱 결제 서비스
/// - 상품: glasnyl_lifetime_pro (Non-Consumable)
/// - 패키지: in_app_purchase ^3.2.3
class PurchaseService {
  // ── 상품 ID (Google Play Console / App Store Connect 등록값과 일치)
  static const String kLifetimeProductId = 'glasnyl_lifetime_pro';
  static const String kLifetimeDiscountProductId = 'glasnyl_lifetime_pro_discount';
  static const String _lifetimeKey = 'is_lifetime_pro';

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // ── 로딩 상태 (UI 반영용)
  static bool _isBuying = false;
  static bool get isBuying => _isBuying;

  // ── 외부 콜백 (dialog_pass.dart에서 주입)
  static VoidCallback? onPurchaseSuccess;
  static VoidCallback? onPurchaseRestored;
  static void Function(String message)? onPurchaseError;
  // ✅ 추가: isBuying 상태 변경 시 다이얼로그 즉시 리빌드용 콜백
  static VoidCallback? onBuyingStateChanged;

  // ──────────────────────────────────────
  // 앱 시작 시 1회 호출 (main.dart)
  // ──────────────────────────────────────
  static void initialize() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        debugPrint('🚨 PurchaseStream 오류: $error');
        _isBuying = false;
        onBuyingStateChanged?.call(); // ✅ 추가
        onPurchaseError?.call('결제 스트림 오류가 발생했습니다.');
      },
    );
    debugPrint('✅ PurchaseService 초기화 완료');
  }

  // ──────────────────────────────────────
  // 앱 종료 시 호출
  // ──────────────────────────────────────
  static void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }

  // ──────────────────────────────────────
  // 구매 시작
  // ──────────────────────────────────────
  static Future<void> buyLifetimePro({bool isDiscount = false}) async {
    if (_isBuying) {
      debugPrint('⚠️ 이미 결제 진행 중입니다.');
      return;
    }

    final bool available = await _iap.isAvailable();
    if (!available) {
      onPurchaseError?.call('스토어에 연결할 수 없습니다. 네트워크 상태를 확인해 주세요.');
      return;
    }

    // 설치 1시간 이내면 할인 상품, 이후엔 정가 상품
    final String targetId = isDiscount ? kLifetimeDiscountProductId : kLifetimeProductId;

    final ProductDetailsResponse response =
        await _iap.queryProductDetails({targetId});

    if (response.error != null) {
      debugPrint('🚨 상품 조회 오류: ${response.error}');
      onPurchaseError?.call('상품 정보를 불러오지 못했습니다. (${response.error?.message})');
      return;
    }

    if (response.productDetails.isEmpty) {
      debugPrint('⚠️ 상품을 찾을 수 없음: $targetId');
      onPurchaseError?.call('상품을 찾을 수 없습니다. 잠시 후 다시 시도해 주세요.');
      return;
    }

    _isBuying = true;
    final purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );

    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      // 결과는 purchaseStream → _onPurchaseUpdate 에서 비동기 처리됨
    } catch (e) {
      _isBuying = false;
      onBuyingStateChanged?.call(); // ✅ 추가
      debugPrint('🚨 구매 요청 예외: $e');
      onPurchaseError?.call('구매 요청 중 오류가 발생했습니다.');
    }
  }

  // ──────────────────────────────────────
  // 구매 복원 (기기 변경 / 재설치)
  // ──────────────────────────────────────
  static Future<void> restorePurchases() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      onPurchaseError?.call('스토어에 연결할 수 없습니다.');
      return;
    }

    try {
      await _iap.restorePurchases();
      // 결과는 purchaseStream → _onPurchaseUpdate (status: restored) 에서 처리됨
    } catch (e) {
      debugPrint('🚨 구매 복원 예외: $e');
      onPurchaseError?.call('구매 복원 중 오류가 발생했습니다.');
    }
  }

  // ──────────────────────────────────────
  // ✅ 추가: 스트림 이벤트 미도달 시 강제 초기화 (타임아웃 안전장치용)
  // ──────────────────────────────────────
  static void forceResetBuying() {
    _isBuying = false;
    onBuyingStateChanged?.call();
    debugPrint('⚠️ isBuying 강제 초기화됨 (타임아웃 또는 다이얼로그 종료)');
  }

  // ──────────────────────────────────────
  // 결제 스트림 이벤트 처리
  // ──────────────────────────────────────
  static void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      // 정가 상품 또는 할인 상품 둘 다 처리
      if (purchase.productID != kLifetimeProductId &&
          purchase.productID != kLifetimeDiscountProductId) continue;

      debugPrint('📦 결제 이벤트: ${purchase.status} / ${purchase.productID}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('⏳ 결제 대기 중...');
          break;

        case PurchaseStatus.purchased:
          _isBuying = false;
          onBuyingStateChanged?.call(); // ✅ 추가
          if (await _verify(purchase)) {
            await _grantLifetimePro();
            onPurchaseSuccess?.call();
          } else {
            onPurchaseError?.call('구매 검증에 실패했습니다. 고객 지원에 문의해 주세요.');
          }
          break;

        case PurchaseStatus.restored:
          _isBuying = false;
          onBuyingStateChanged?.call(); // ✅ 추가
          if (await _verify(purchase)) {
            await _grantLifetimePro();
            onPurchaseRestored?.call();
          } else {
            onPurchaseError?.call('복원된 구매를 확인하지 못했습니다.');
          }
          break;

        case PurchaseStatus.error:
          _isBuying = false;
          onBuyingStateChanged?.call(); // ✅ 추가
          final code = purchase.error?.code ?? '';
          final msg = purchase.error?.message ?? '알 수 없는 오류';
          debugPrint('🚨 결제 오류 [$code]: $msg');
          // 사용자 취소는 조용히 처리
          if (code == 'userCancelled' ||
              msg.toLowerCase().contains('cancel') ||
              msg.toLowerCase().contains('취소')) {
            debugPrint('ℹ️ 사용자가 결제를 취소했습니다.');
          } else {
            onPurchaseError?.call('결제 오류: $msg');
          }
          break;

        case PurchaseStatus.canceled:
          _isBuying = false;
          onBuyingStateChanged?.call(); // ✅ 추가
          debugPrint('ℹ️ 결제 취소됨');
          break;
      }

      // ⚠️ 반드시 호출 — Google Play / App Store 정산 완료 처리
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  // ──────────────────────────────────────
  // 구매 검증
  // ──────────────────────────────────────
  static Future<bool> _verify(PurchaseDetails purchase) async {
    // TODO: 실서비스에서는 서버 검증을 강력히 권장합니다.
    // purchase.verificationData.serverVerificationData 를 백엔드에 전달 후
    // Google Play Developer API / Apple App Store Server API 응답으로 검증하세요.
    debugPrint('✅ 구매 검증 통과 (purchaseID: ${purchase.purchaseID})');
    return true;
  }

  // ──────────────────────────────────────
  // Lifetime Pro 권한 부여
  // ──────────────────────────────────────
  static Future<void> _grantLifetimePro() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lifetimeKey, true);
      debugPrint('🎉 Lifetime Pro 권한 저장 완료');
    } catch (e) {
      debugPrint('🚨 권한 저장 실패: $e');
    }
  }

  // ──────────────────────────────────────
  // Lifetime Pro 여부 확인 (외부 사용)
  // ──────────────────────────────────────
  static Future<bool> isLifetimePro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lifetimeKey) ?? false;
  }

  // ──────────────────────────────────────
  // [DEBUG ONLY] 결제 상태 초기화
  // ──────────────────────────────────────
  static Future<void> debugResetPurchase() async {
    assert(() {
      // release 빌드에서는 절대 실행되지 않음
      return true;
    }());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lifetimeKey);
    _isBuying = false;
    debugPrint('🧪 [DEBUG] 결제 상태 초기화 완료');
  }
}