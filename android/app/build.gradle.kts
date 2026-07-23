import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // key.properties(gitignore対象)経由でuploadキーストアを参照する。
            // ファイルが存在しない環境(CI未設定時等)ではdebug鍵にフォールバック。
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
    // google_mobile_ads が WorkManager を暗黙に要求するが work-runtime 本体を
    // 引き込まないため、明示的に追加してWorkDatabase初期化クラッシュを防ぐ。
    implementation("androidx.work:work-runtime:2.11.1")
}
