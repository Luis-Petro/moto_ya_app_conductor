import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Services (FCM) se aplica SOLO si existe google-services.json
// (package_name = com.zumbeo.conductor). Así el build sigue funcionando sin FCM
// —igual que el resto del proyecto, donde el push es opcional— y se activa en
// cuanto se coloca el archivo en android/app/.
// El archivo es el del proyecto Firebase `zumbeo-2a176` y trae los dos clientes
// (com.zumbeo.cliente y com.zumbeo.conductor): el plugin escoge el que coincide con
// el applicationId, así que las dos apps llevan el mismo archivo. Nunca editar el
// package_name a mano — el mobilesdk_app_id y la api_key son por app, y un archivo
// retocado registra los tokens contra la app equivocada sin que nada falle.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Claves de firma para el release. Viven FUERA del repo (android/key.properties,
// ignorado por git); en CI se materializa el archivo desde secrets. Sin ellas el
// release se firma con la clave de debug, que sirve para `flutter run --release`
// pero Google Play rechaza: ver el aviso en buildTypes.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) {
        f.inputStream().use { load(it) }
    }
}
val hayFirmaRelease = keystoreProperties.getProperty("storeFile") != null

android {
    // Esta es la app del conductor: antes el namespace decía app_cliente, así que
    // BuildConfig, la clase R y cualquier traza salían con la identidad equivocada.
    namespace = "com.zumbeo.conductor"
    // API 36 explícito: desde el 31-ago-2026 Google Play no acepta apps nuevas ni
    // actualizaciones que apunten por debajo. No se deja en flutter.compileSdkVersion
    // para que subir de Flutter no mueva el target sin que nos enteremos.
    compileSdk = 36
    // NDK fijado (= flutter.ndkVersion en Flutter 3.32) para que el caché de CI
    // tenga una clave estable y no lo reinstale en cada corrida.
    ndkVersion = "26.3.11579264"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.zumbeo.conductor"
        // minSdk 23: requerido por firebase_messaging, geolocator y flutter_secure_storage.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = 36
        // El versionCode lo puede sobreescribir el CI (--build-number) porque Play
        // exige uno mayor en cada subida; el versionName sigue saliendo del
        // pubspec, que es donde se declara la versión a mano.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayFirmaRelease) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hayFirmaRelease) {
                signingConfigs.getByName("release")
            } else {
                // Sin key.properties se firma con debug para que el release local
                // arranque. Un artefacto así NO se puede subir a Play (lo rechaza
                // por estar firmado en modo debug); el aviso de abajo lo recuerda.
                logger.warn(
                    "⚠️  android/key.properties no existe: el release se firmará con la " +
                        "clave de debug y Google Play lo rechazará. Solo sirve para pruebas locales."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
