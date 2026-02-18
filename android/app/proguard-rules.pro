# ---------------------------------------------------------
# 1. 빌드 중단 방지 및 경고 무시 (R8 Missing Class 에러 해결)
# ---------------------------------------------------------
-ignorewarnings
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ---------------------------------------------------------
# 2. 기존 알림 서비스 규칙 (Notification Listener)
# ---------------------------------------------------------
-keep class notification.listener.service.** { *; }
-keep public class * extends android.service.notification.NotificationListenerService

# ---------------------------------------------------------
# 3. Flutter 기본 규칙 (Core Engine & Plugins)
# ---------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ---------------------------------------------------------
# 4. AdMob (Google Mobile Ads) 필수 규칙
# ---------------------------------------------------------
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep class com.google.android.play.core.** { *; }

# ---------------------------------------------------------
# 5. 기타 필수 규칙 (Shared Preferences 등)
# ---------------------------------------------------------
-keep class com.russhwolf.settings.** { *; }

# ---------------------------------------------------------
# 6. 추가적인 코드 최적화 예외 (필요 시)
# ---------------------------------------------------------
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses