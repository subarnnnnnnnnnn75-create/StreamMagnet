# StreamMagnet ProGuard / R8 Rules

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# MediaKit / mpv
-keep class com.alexmercerind.media_kit.** { *; }

# Torrent Engine (jlibtorrent / libtorrent)
-keep class com.frostwire.jlibtorrent.** { *; }
-keep class com.frostwire.jlibtorrent.swig.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# AndroidX Media & Notifications
-keep class androidx.media.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }

# WebView
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
