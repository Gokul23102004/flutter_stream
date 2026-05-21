plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.stream"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // ✅ CHANGE 1: Fixed deprecated jvmTarget syntax
        // OLD (caused deprecation warning): jvmTarget = JavaVersion.VERSION_17.toString()
        // NEW: Use plain string directly
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.stream"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// ✅ CHANGE 2: Moved configurations.all OUTSIDE the android {} block
// In Kotlin DSL (.kts), configurations.all must be at the top level, not nested inside android {}

// ✅ CHANGE 3: Fixed Groovy syntax → Kotlin DSL syntax
// Groovy:      force 'group:artifact'
// Kotlin DSL:  force("group:artifact")   ← parentheses + double quotes

// ✅ CHANGE 4: Fixed exclude syntax
// Groovy:      exclude group: 'x', module: 'y'
// Kotlin DSL:  exclude(group = "x", module = "y")  ← = sign + double quotes

configurations.all {
    resolutionStrategy {
        force("androidx.core:core:1.13.1")
        force("androidx.versionedparcelable:versionedparcelable:1.1.1")
    }
    exclude(group = "com.android.support", module = "support-compat")
    exclude(group = "com.android.support", module = "versionedparcelable")
}

flutter {
    source = "../.."
}
