plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.voikerchat"
    // firebase_core/firebase_messaging と androidx 群が compileSdk>=34 を要求するため
    // 明示的に 36 を指定（flutter.compileSdkVersion が 33 に解決され不足するため）
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications が要求する core library desugaring を有効化
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Firebase registered package name
        applicationId = "jp.shibuyer.voikerchat"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // google_mobile_ads (Google Mobile Ads SDK) requires Android minSdk 23.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // core library desugaring 用ライブラリ（flutter_local_notifications 要件）
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
