allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    // 古い Firebase/プラグインの android モジュールが compileSdk 33 で固定され、
    // 新しい androidx 依存（>=34要件）と衝突するため、全サブプロジェクトに 36 を強制。
    // afterEvaluate は evaluationDependsOn より前の独立ブロックで登録する
    //（同ブロック内で後置すると "Cannot run afterEvaluate when already evaluated"）。
    afterEvaluate {
        val androidExtension = extensions.findByName("android")
        if (androidExtension is com.android.build.gradle.BaseExtension) {
            androidExtension.compileSdkVersion(36)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
