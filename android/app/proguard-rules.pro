# Keep ML Kit Text Recognition related classes
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# Keep ML Kit general classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.mlkit.vision.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Keep generated MLKit files
-keep class com.google_mlkit_** { *; }

# Keep unused ML Kit model classes
-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }

# Prevent R8 from failing on missing classes
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Prevent R8 from failing on missing FirebaseInstanceId (used by ML Kit)
-dontwarn com.google.firebase.iid.**
-dontwarn com.google.mlkit.linkfirebase.internal.**
-dontwarn com.google.android.gms.internal.mlkit_linkfirebase.**

# Keep all Firebase and Google classes (for safety)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# General optimization rules
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification

# Remove unnecessary attributes from classes
-keepattributes Signature,InnerClasses,Exceptions
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Remove unused code
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Remove specific language models if not using them
# Uncomment these if you DON'T need these languages:
# -keep,includedescriptorclasses,allowobfuscation class com.google.mlkit.vision.text.chinese.** { *; }
# -keep,includedescriptorclasses,allowobfuscation class com.google.mlkit.vision.text.devanagari.** { *; }
# -keep,includedescriptorclasses,allowobfuscation class com.google.mlkit.vision.text.japanese.** { *; }
# -keep,includedescriptorclasses,allowobfuscation class com.google.mlkit.vision.text.korean.** { *; }