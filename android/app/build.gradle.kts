plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.happ"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Enable desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
        // Do NOT set languageVersion or apiVersion to 1.8 or 1.9, let it use the default for 2.0
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.happ"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // Add these lines to reduce optimization
            isShrinkResources = true
            isMinifyEnabled = true
            
            // Enable this if you need to see debug info
            // isDebuggable = true
        }
    }
    
    // Add this for smaller builds
    packagingOptions {
        resources {
            excludes += listOf(
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/DEPENDENCIES",
                "META-INF/*.kotlin_module",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Desugaring library for Java 8+ features on older Android
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // Use Firebase BOM to manage versions
    implementation(platform("com.google.firebase:firebase-bom:32.7.3"))
    
    // Essential Firebase components with explicit exclusions
    implementation("com.google.firebase:firebase-messaging") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
    
    implementation("com.google.firebase:firebase-auth") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
    
    // implementation("com.google.firebase:firebase-core") {
    //     exclude(group = "com.google.firebase", module = "firebase-iid")
    // }
    
    implementation("com.google.firebase:firebase-storage") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
    
    implementation("com.google.firebase:firebase-firestore") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
    
    // ML Kit dependencies
    implementation("com.google.mlkit:text-recognition-chinese:16.0.0") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.0") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
    implementation("com.google.mlkit:text-recognition-japanese:16.0.0") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
    implementation("com.google.mlkit:text-recognition-korean:16.0.0") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
}

// Add configuration to force resolution of conflicts
configurations.all {
    resolutionStrategy {
        // Force the latest version and exclude the problematic one
        force("com.google.firebase:firebase-messaging:24.1.1")
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
}
