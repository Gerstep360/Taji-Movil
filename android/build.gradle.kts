allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Permite una compilación aislada si Windows mantiene bloqueados artefactos antiguos.
val newBuildDir: Directory = providers.gradleProperty("tajiBuildDir").orNull
    ?.let { rootProject.layout.projectDirectory.dir(it) }
    ?: rootProject.layout.buildDirectory.dir("../../build").get()
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
