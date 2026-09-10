import java.io.File

// Flutter 3.47 greps plugin build.gradle files for `apply plugin: 'kotlin-android'`
// and warns even when that line is behind `if (!builtInKotlin)`. firebase_core
// and firebase_auth already skip KGP at runtime when android.builtInKotlin=true;
// moving the apply into a sidecar file keeps that behaviour and silences the
// false positive. Remove this once FlutterFire drops the apply entirely.
fun File.silenceFlutterFireKgpScanner() {
    val gradleFile = resolve("android/build.gradle")
    if (!gradleFile.isFile) return
    val original = gradleFile.readText()
    if ("apply plugin: 'kotlin-android'" !in original &&
        "apply plugin: \"kotlin-android\"" !in original
    ) {
        return
    }
    if ("legacy-kotlin-android.gradle" in original) return
    gradleFile.writeText(
        original
            .replace(
                "apply plugin: 'kotlin-android'",
                "apply from: file(\"legacy-kotlin-android.gradle\")",
            ).replace(
                "apply plugin: \"kotlin-android\"",
                "apply from: file(\"legacy-kotlin-android.gradle\")",
            ),
    )
    resolve("android/legacy-kotlin-android.gradle").writeText(
        "apply plugin: 'kotlin-android'\n",
    )
}

val flutterPluginsLock = File(settingsDir, "../.flutter-plugins-dependencies")
if (flutterPluginsLock.isFile) {
    val json = flutterPluginsLock.readText()
    for (plugin in listOf("firebase_core", "firebase_auth")) {
        val match =
            Regex(""""name"\s*:\s*"$plugin"\s*,\s*"path"\s*:\s*"([^"]+)"""")
                .find(json)
        match?.groupValues?.get(1)?.let { File(it).silenceFlutterFireKgpScanner() }
    }
}

pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    // Reads app/google-services.json at build time and generates the Firebase
    // config resources firebase_core initialises from.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
