import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties, which points at the
// keystore outside the repository. Both are git-ignored and must never be
// committed.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.mmi.haraplay"
    // permission_handler_android 14.x requires compiling against API 37.
    // targetSdk (runtime behaviour) stays at the Flutter default.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mmi.haraplay"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // The launcher label (AndroidManifest uses ${appName}).
        manifestPlaceholders["appName"] = "HaraPlay"
    }

    signingConfigs {
        if (keyProperties.isNotEmpty()) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Debug builds are a separate app, "HaraPlay Dev"
        // (com.mmi.haraplay.debug), so they install next to the release
        // app with their own data. Its icon lives in src/debug/res.
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-dev"
            manifestPlaceholders["appName"] = "HaraPlay Dev"
        }
        release {
            // Without key.properties the release APK stays unsigned (it
            // won't install) instead of silently being debug-signed.
            signingConfig = signingConfigs.findByName("release")
            // HARAPLAY_DEV_RELEASE=true: a release-mode build of HaraPlay
            // Dev (debug key), to measure release performance without
            // replacing the release app.
            if (System.getenv("HARAPLAY_DEV_RELEASE") == "true") {
                applicationIdSuffix = ".debug"
                versionNameSuffix = "-dev-release"
                manifestPlaceholders["appName"] = "HaraPlay Dev"
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // JVM unit tests (android/app/src/test): ./gradlew :app:testDebugUnitTest
    testImplementation("junit:junit:4.13.2")
}
