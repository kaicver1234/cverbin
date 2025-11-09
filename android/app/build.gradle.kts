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
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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
        versionCode = 4
        versionName = "1.1.1"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists() && keystoreProperties.isNotEmpty()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // ⚠️ TEMPORARY: Using debug key for compatibility with existing installation
            // Change this back to release key after users update or reinstall
            signingConfig = signingConfigs.getByName("debug")
            
            // Uncomment below to use production release key:
            // if (keystorePropertiesFile.exists() && keystoreProperties.isNotEmpty()) {
            //     signingConfig = signingConfigs.getByName("release")
            // }
            
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
    
    packaging {
        resources {
            excludes += setOf(
                "META-INF/NOTICE",
                "META-INF/LICENSE",
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE.txt"
            )
        }
        jniLibs {
            // Fix: Handle duplicate libgojni.so from DXcore and libv2ray
            // Use DXcore's libgojni.so (prioritize DXcore for Tiksar Smart)
            pickFirsts += setOf(
                "lib/armeabi-v7a/libgojni.so",
                "lib/arm64-v8a/libgojni.so",
                "lib/x86/libgojni.so",
                "lib/x86_64/libgojni.so"
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
    
    // DXcore library for Defyx VPN protocols (XRAY, OUTLINE, PSIPHON, WARP, GOOL, SERVERLESS)
    implementation(files("libs/DXcore.aar"))
}
