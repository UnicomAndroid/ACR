# Xposed
-adaptresourcefilecontents META-INF/xposed/java_init.list
-keepattributes RuntimeVisibleAnnotations
-keep,allowobfuscation,allowoptimization public class * extends io.github.libxposed.api.XposedModule {
    public <init>(...);
    public void onPackageLoaded(...);
    public void onSystemServerLoaded(...);
}
-keep,allowoptimization,allowobfuscation @io.github.libxposed.api.annotations.* class * {
    @io.github.libxposed.api.annotations.BeforeInvocation <methods>;
    @io.github.libxposed.api.annotations.AfterInvocation <methods>;
}

# Kotlin
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
	public static void check*(...);
	public static void throw*(...);
}
-assumenosideeffects class java.util.Objects {
    public static ** requireNonNull(...);
}

# Strip debug log
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
}

# Obfuscation
-repackageclasses
-allowaccessmodification

# Keep libphonenumber-android metadata (stored in assets)
-keepresourcefiles assets/io/michaelrocks/libphonenumber/android/**

# BCR migrated classes — keep TAG fields used in logging and RecorderThread class
-keepclasseswithmembers,allowoptimization,allowshrinking class studio.unicom.acr.** {
    static final java.lang.String TAG;
}
-keep,allowoptimization,allowshrinking class studio.unicom.acr.service.RecorderThread {}
-keepclassmembers class androidx.documentfile.provider.SingleDocumentFile {
    private android.content.Context mContext;
}
-keepclassmembers class androidx.documentfile.provider.TreeDocumentFile {
    <init>(androidx.documentfile.provider.DocumentFile, android.content.Context, android.net.Uri);
    private android.content.Context mContext;
}