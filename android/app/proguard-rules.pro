# Section 67: release builds with minification enabled can silently break
# the WebView JS bridge, FCM, and billing if these classes get stripped or
# renamed. ALWAYS smoke-test a release build (login, push, sandbox
# purchase) before uploading — `flutter build appbundle --release`
# "succeeding" does not mean these still work. See docs/ANDROID_BUILD.md.

# --- WebView JavaScript interface -----------------------------------
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class io.flutter.plugins.webviewflutter.** { *; }

# --- Firebase Cloud Messaging -----------------------------------------
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --- Google Play Billing ------------------------------------------------
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# --- in_app_purchase plugin ---------------------------------------------
-keep class io.flutter.plugins.inapppurchase.** { *; }

# --- flutter_local_notifications -----------------------------------------
-keep class com.dexterous.** { *; }

# --- General Flutter plugin registrant (safe default for all plugins) ---
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.embedding.** { *; }

-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task