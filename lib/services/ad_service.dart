import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class AdService {
  static const String _adKey = "last_ad_watch_time";
  static const String _lifetimeKey = "is_lifetime_pro";
  static const String _installTimeKey = "app_install_time";

  static String get rewardedAdUnitId => 'ca-app-pub-3940256099942544/5224354917';

  static bool _isAdLoading = false;
  static int _watchedCount = 0;

  static int get watchedCount => _watchedCount;

  /// 앱 설치 시간 초기화
  static Future<void> initInstallTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_installTimeKey) == null) {
        await prefs.setString(_installTimeKey, DateTime.now().toIso8601String());
      }
    } catch (e) {
      debugPrint("InitInstallTime Error: $e");
    }
  }

  /// 가격 정보 가져오기 (설치 후 1시간 동안 할인 적용)
  static Future<Map<String, dynamic>> getPriceInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? installTimeStr = prefs.getString(_installTimeKey);
      
      if (installTimeStr == null) {
        return {'isDiscount': false, 'price': "\$9.99"};
      }

      DateTime installTime = DateTime.parse(installTimeStr);
      // 🔥 1분 -> 1시간(60분)으로 수정
      bool isWithinHour = DateTime.now().difference(installTime).inHours < 1;

      return {
        'isDiscount': isWithinHour,
        'price': isWithinHour ? "\$6.99" : "\$9.99",
        'installTime': installTime,
      };
    } catch (e) {
      return {'isDiscount': false, 'price': "\$9.99"};
    }
  }

  /// 권한 확인 (무료 체험 1시간, 광고 혜택 3시간 체크)
  static Future<bool> isFullAccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final isLifetime = prefs.getBool(_lifetimeKey) ?? false;
      if (isLifetime) return true;

      final String? installTimeStr = prefs.getString(_installTimeKey);
      if (installTimeStr != null) {
        final installTime = DateTime.tryParse(installTimeStr);
        // 🔥 무료 체험: 1분 -> 1시간으로 수정
        if (installTime != null && DateTime.now().difference(installTime).inHours < 1) {
          return true;
        }
      }

      final String? lastWatch = prefs.getString(_adKey);
      if (lastWatch != null) {
        final lastWatchDate = DateTime.tryParse(lastWatch);
        // 🔥 광고 혜택: 3분 -> 3시간으로 수정
        if (lastWatchDate != null && DateTime.now().difference(lastWatchDate).inHours < 3) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint("🚨 권한 체크 에러: $e");
      return false;
    }
  }

  /// 광고 프로세스 시작
  static Future<void> startAdProcess(BuildContext context, {required Function onComplete}) async {
    if (_isAdLoading) {
      debugPrint("⚠️ 광고가 이미 로딩 중입니다.");
      return;
    }
    
    bool isAuthorized = await isFullAccess();
    if (isAuthorized) {
       _watchedCount = 0;
    }

    _loadAndShowAd(context, onComplete);
  }

  static void _loadAndShowAd(BuildContext context, Function onComplete) async {
    if (_isAdLoading) return;
    _isAdLoading = true;

    BuildContext? dialogContext;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (ctx, anim1, anim2) {
        dialogContext = ctx;
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      },
    );

    Future.delayed(const Duration(seconds: 10), () {
      if (_isAdLoading) {
        _isAdLoading = false;
        if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
          Navigator.of(dialogContext!).pop();
          _showErrorSnackBar(context, "광고 응답 지연으로 취소되었습니다.");
        }
      }
    });

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (_isAdLoading) {
            _isAdLoading = false;
            if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
              Navigator.of(dialogContext!).pop();
            }
            
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (_watchedCount < 2) {
                  _showErrorSnackBar(context, "광고 1회 시청 완료! 한 번 더 시청해주세요. ($_watchedCount/2)");
                } else {
                  _saveAdWatchTime(onComplete);
                }
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _isAdLoading = false;
                _showErrorSnackBar(context, "광고 재생 실패");
              },
            );

            ad.show(onUserEarnedReward: (ad, r) {
              _watchedCount++;
            });
          }
        },
        onAdFailedToLoad: (err) {
          if (_isAdLoading) {
            _isAdLoading = false;
            if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
              Navigator.of(dialogContext!).pop();
            }
            _showErrorSnackBar(context, "광고 로드 실패");
          }
        },
      ),
    );
  }

  static Future<void> _saveAdWatchTime(Function onComplete) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_adKey, DateTime.now().toIso8601String());
      _watchedCount = 0;
      debugPrint("✅ 광고 시청 보상 저장 완료");
      onComplete();
    } catch (e) {
      debugPrint("🚨 보상 저장 중 오류 발생: $e");
      onComplete();
    }
  }

  /// 광고 서비스 지연 초기화 (음악 서비스와의 충돌 방지)
  static Future<void> initAdmobWithDelay() async {
    // 🚀 앱 실행 후 5초 대기 (네이티브 미디어 세션이 안정화될 충분한 시간)
    await Future.delayed(const Duration(seconds: 5));
    
    try {
      await MobileAds.instance.initialize();
      // 테스트 기기 설정 (빌드 시 본인의 기기 ID로 유지하세요)
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: ["BF31176F5CBEAAC1A0FABF84A52C1EBF"]),
      );
      debugPrint("✅ AdMob이 음악 세션 뒤에 안전하게 로드되었습니다.");
    } catch (e) {
      debugPrint("🚨 AdMob 초기화 실패: $e");
    }
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  /// 만료 시간 계산 (UI 표시용)
  static Future<DateTime?> getPassExpiryTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_lifetimeKey) ?? false) return DateTime.now().add(const Duration(days: 365));

      String? installTimeStr = prefs.getString(_installTimeKey);
      // 🔥 무료 체험 만료: 1시간(60분) 뒤
      DateTime? installExpiry = installTimeStr != null 
          ? DateTime.parse(installTimeStr).add(const Duration(hours: 1)) 
          : null;

      String? lastWatch = prefs.getString(_adKey);
      // 🔥 광고 혜택 만료: 3시간 뒤
      DateTime? adExpiry = lastWatch != null 
          ? DateTime.parse(lastWatch).add(const Duration(hours: 3)) 
          : null;

      if (installExpiry == null && adExpiry == null) return null;
      if (installExpiry != null && adExpiry == null) return installExpiry;
      if (installExpiry == null && adExpiry != null) return adExpiry;
      
      return installExpiry!.isAfter(adExpiry!) ? installExpiry : adExpiry;
    } catch (e) {
      return null;
    }
  }
}