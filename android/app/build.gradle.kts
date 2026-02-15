import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Read secrets (e.g. the Google Maps API key) from the gitignored
// local.properties so they never live in version control.
val localProperties = Properties()
rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use {
    localProperties.load(it)
}
val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY") ?: ""

android {
    namespace = "com.vitbhopal.vbusf"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Keep native libs page-aligned inside the APK instead of extracting
    // them to /data/app/.../lib/ on install — halves installed size.
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    defaultConfig {
        applicationId = "com.vitbhopal.vbusf"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Injected into AndroidManifest.xml as ${MAPS_API_KEY}.
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey

        // Drop x86, x86_64, armeabi-v7a copies of every native lib
        // (especially libmlkit_google_ocr_pipeline.so which the plugin
        // ignores Flutter's --target-platform flag for).
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Unbundled ML Kit text recognition — model + native pipeline are
    // downloaded by Google Play Services on demand instead of bundled.
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1")
}

// Force the unbundled flavour by excluding the bundled module that
// google_mlkit_text_recognition pulls in transitively.
configurations.all {
    exclude(group = "com.google.mlkit", module = "text-recognition")
}
