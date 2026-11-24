# Flutter / Android Proguard Rules for Notlyfe

# Preserve Generic Signatures for Gson & TypeToken in flutter_local_notifications
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }

# Google Gson
-keep class com.google.gson.** { *; }
-keepclassmembers class * extends com.google.gson.reflect.TypeToken { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Flutter Secure Storage
-keep class androidx.security.crypto.** { *; }

# Google Sign In
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class androidx.credentials.** { *; }

