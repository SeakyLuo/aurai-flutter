# Shizuku constructs the user service by its declared class name.
-keep class com.haiskynology.aurai.PrivilegedShellService { *; }
# JNI entry points use these names.
-keep class com.haiskynology.aurai.TunnelEngine { *; }
# PDF text extraction does not use the optional JPEG 2000 image decoder.
-dontwarn com.gemalto.jp2.JP2Decoder

# HTML games expose only the annotated event bridge to JavaScript.
-keepclassmembers class com.haiskynology.aurai.HtmlGameView$* {
    @android.webkit.JavascriptInterface <methods>;
}
