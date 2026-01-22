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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    // afterEvaluate를 쓰지 않고 직접 구성에 접근합니다.
    plugins.withType<com.android.build.gradle.api.AndroidBasePlugin> {
        val android = extensions.getByType<com.android.build.gradle.BaseExtension>()
        
        // 빌드 시작 시점에 네임스페이스가 없으면 강제로 할당
        if (android.namespace == null) {
            android.namespace = project.group.toString()
        }
    }
}