import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load keystore properties from key.properties file
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
var useReleaseKeystore = false

if (keystorePropertiesFile.exists()) {
    try {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
        val storeFilePath = keystoreProperties.getProperty("storeFile")
        if (storeFilePath != null) {
            val keystoreFile = rootProject.file(storeFilePath)
            useReleaseKeystore = keystoreFile.exists()
            if (!useReleaseKeystore) {
                println("⚠️ Keystore file not found: $storeFilePath - Using debug signing")
            }
        }
    } catch (e: Exception) {
        println("⚠️ Error loading keystore properties: ${e.message} - Using debug signing")
    }
}

android {
    namespace = "com.tiksarvpn.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Application ID for Tiksar VPN
        applicationId = "com.tiksarvpn.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 8
        versionName = "1.1.1"
    }

    signingConfigs {
        if (useReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // ✅ Use release signing config for production builds
            // This prevents Google Play Protect warnings
            signingConfig = if (useReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                println("⚠️ Building with debug signing - APK will show Play Protect warning")
                signingConfigs.getByName("debug")
            }

            // Disable minify for VPN apps to avoid compatibility issues
            isMinifyEnabled = false
            isShrinkResources = false
        }
        
        debug {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
        disable += listOf(
            "GoogleAppIndexingWarning",
            "UnusedAttribute",
            "MissingApplicationIcon"
        )
    }

    packagingOptions {
        resources {
            excludes += listOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/*.kotlin_module"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
