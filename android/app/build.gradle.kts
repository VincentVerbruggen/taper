plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vincent.taper"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable core library desugaring — required by flutter_local_notifications.
        // This is like a polyfill: it backports newer Java APIs (java.time, etc.)
        // to older Android versions that don't have them natively.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vincent.taper"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        // Debug builds get a ".dev" suffix so they install as a separate app
        // on your phone alongside the release version. Think of it like
        // Laravel's APP_ENV — same code, different identity.
        debug {
            applicationIdSuffix = ".dev"
            // This changes the app name in the launcher so you can tell them apart
            resValue("string", "app_name", "Taper DEV")
        }

        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            resValue("string", "app_name", "Taper")
        }
    }
}

// The desugar_jdk_libs dependency provides the actual polyfill implementations
// that isCoreLibraryDesugaringEnabled references. Without this, the build knows
// it SHOULD desugar but doesn't have the library to do it with.
// Like adding a Composer package that a plugin declared as a requirement.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
