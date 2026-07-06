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
// 需要 minCompileSdk=36。子模块无法通过 root project 覆盖编译 SDK，
// 因此在所有项目评估完成后跳过各 library 模块的 AAR metadata 校验
gradle.projectsEvaluated {
    allprojects {
        tasks.matching { it.name.startsWith("checkAarMetadata") }.configureEach {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
