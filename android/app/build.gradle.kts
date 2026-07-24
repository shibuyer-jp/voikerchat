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
            // 以前は未検出時にdebug鍵へ暗黙フォールバックしていたが、debug署名済みの
            // AABをPlay Consoleにアップロードして初めて気づく事故を招くため廃止した。
            // key.properties が無い場合は下の taskGraph チェックでビルドを停止する。
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// release成果物を作るタスクが要求された場合に限り、key.properties の存在を検証する。
// 設定フェーズで無条件に例外を投げると debug ビルドや flutter analyze まで巻き込むため、
// タスクグラフ確定後に判定する。
gradle.taskGraph.whenReady {
    val wantsRelease = allTasks.any { task ->
        val n = task.name
        n.endsWith("Release") &&
            (n.startsWith("assemble") || n.startsWith("bundle") || n.startsWith("package"))
    }
    if (wantsRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            buildString {
                appendLine("release ビルドに必要な android/key.properties が見つかりません。")
                appendLine("期待パス: ${keystorePropertiesFile.absolutePath}")
                appendLine()
                appendLine("upload keystore は %USERPROFILE%\\Voikerchat-Release-Keys\\ に保管しています。")
                appendLine("android/key.properties を以下の形式で作成してください（このファイルはコミット禁止）:")
                appendLine("  storeFile=<キーストアの絶対パス>")
                appendLine("  storePassword=<ストアパスワード>")
                appendLine("  keyAlias=<エイリアス>")
                appendLine("  keyPassword=<キーパスワード>")
                appendLine()
                append("※ 以前は debug 鍵へ自動フォールバックしていましたが、")
                append("debug署名のAABはPlayが受理しないため、明示的に失敗させる方針に変更しました。")
            }
        )
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
