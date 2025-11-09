# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /usr/local/Cellar/android-sdk/24.3.3/tools/proguard/proguard-android.txt

## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

## Keep Go runtime classes from both DXcore and libv2ray
## R8 will automatically handle duplicates by keeping only one copy
-keep class go.** { *; }
-dontwarn go.**

## Keep V2Ray classes
-keep class libv2ray.** { *; }
-dontwarn libv2ray.**

## Keep DXcore classes  
-keep class com.dxcore.** { *; }
-dontwarn com.dxcore.**

## Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

## Keep Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

## Keep Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

## Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

## AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**

## Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

## Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
}
