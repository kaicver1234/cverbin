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
        // DXcore requires minSdk 23
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = 4
        versionName = "1.1.1"
        multiDexEnabled = true
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
            
            // Disable minify to avoid duplicate class check issues
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
            // Prioritize DXcore's Go runtime classes over libv2ray's
            pickFirsts += setOf(
                "go/Seq.class",
                "go/Seq\$GoObject.class",
                "go/Seq\$GoRef.class",
                "go/Seq\$GoRefQueue.class",
                "go/Seq\$GoRefQueue\$1.class",
                "go/Seq\$Proxy.class",
                "go/Seq\$Ref.class",
                "go/Seq\$RefMap.class",
                "go/Seq\$RefTracker.class",
                "go/Universe.class",
                "go/Universe\$proxyerror.class",
                "go/error.class"
            )
        }
        jniLibs {
            // Prioritize DXcore's native libraries over libv2ray's
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

// Disable duplicate class and dex checks
// Both DXcore and libv2ray have Go runtime, but we handle this via packaging.pickFirsts
gradle.taskGraph.whenReady {
    allTasks.forEach { task ->
        val taskName = task.name
        if (taskName.contains("checkReleaseDuplicateClasses") || 
            taskName.contains("checkDebugDuplicateClasses")) {
            task.enabled = false
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("androidx.multidex:multidex:2.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // DXcore library for VPN protocols (XRAY, OUTLINE, PSIPHON, WARP, GOOL, SERVERLESS)
    // Note: libv2ray is disabled to avoid duplicate Go runtime conflict
    // DXcore's XRAY supports all V2Ray protocols (vmess, vless, trojan, shadowsocks)
    implementation(files("libs/DXcore.aar"))
}
