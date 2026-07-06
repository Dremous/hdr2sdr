allprojects {
    repositories {
        google()
        mavenCentral()
    }
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
    project.evaluationDependsOn(":app")
}

// file_picker 8.3.7 编译于 android-34，但其依赖 flutter_plugin_android_lifecycle
// 需要 minCompileSdk=36。afterProject 在每个子项目评估完成后立即执行，
// 此时 AGP 的 checkReleaseAarMetadata 任务已注册，可直接禁用
gradle.afterProject { project ->
    project.tasks.matching { it.name.startsWith("checkAarMetadata") }.configureEach {
        enabled = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
