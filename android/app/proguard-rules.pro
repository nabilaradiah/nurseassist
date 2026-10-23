# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Play Store split install (not used in direct APK distribution)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# TFLite
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# Camera
-keep class androidx.camera.** { *; }

# Keep model classes (Dart-generated)
-keepattributes *Annotation*
-keepattributes Signature
