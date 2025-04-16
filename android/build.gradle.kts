allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // Add global resolution strategy
    configurations.all {
        resolutionStrategy {
            // Force the latest version of Firebase Messaging
            force("com.google.firebase:firebase-messaging:24.1.1") 
            // Exclude the problematic dependency globally
            exclude(group = "com.google.firebase", module = "firebase-iid")
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
