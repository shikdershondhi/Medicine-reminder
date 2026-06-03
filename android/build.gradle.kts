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

subprojects {
    val proj = this
    if (proj.state.executed) {
        configureAndroidProject(proj)
    } else {
        proj.afterEvaluate {
            configureAndroidProject(proj)
        }
    }
}

fun configureAndroidProject(proj: Project) {
    val android = proj.extensions.findByName("android")
    if (android != null) {
        val methods = android.javaClass.methods.filter { it.name == "compileSdk" || it.name == "compileSdkVersion" }
        for (method in methods) {
            try {
                val params = method.parameterTypes
                if (params.size == 1) {
                    if (params[0] == Int::class.javaPrimitiveType || params[0] == Integer::class.java) {
                        method.invoke(android, 36)
                    } else if (params[0] == String::class.java) {
                        method.invoke(android, "android-36")
                    }
                }
            } catch (e: Exception) {
                // Fail-safe check
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
