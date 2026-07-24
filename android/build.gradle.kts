allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Force plugins (e.g. connectivity_plus) to compile against API 36 —
// androidx.core 1.18.0 requires compileSdk >= 36; Flutter's default is still 35.
// Must run after each plugin's android {} block, so use afterEvaluate (or configure
// immediately if evaluationDependsOn already evaluated the project).
fun Project.forceCompileSdk36() {
    val android = extensions.findByName("android") ?: return
    try {
        android.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType).invoke(android, 36)
    } catch (_: NoSuchMethodException) {
        try {
            @Suppress("DEPRECATION")
            android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType).invoke(android, 36)
        } catch (_: NoSuchMethodException) {
            // Not an Android subproject
        }
    }
}

subprojects {
    if (state.executed) {
        forceCompileSdk36()
    } else {
        afterEvaluate { forceCompileSdk36() }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
