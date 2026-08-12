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
    // AGP 8.9.x es la primera serie que soporta compilar contra Android 16 (API 36),
    // que es lo que Play exige desde el 31-ago-2026. Necesita Gradle ≥ 8.11.1 y el
    // wrapper ya está en 8.12.
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // Google Services: procesa google-services.json en build time para habilitar FCM.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
