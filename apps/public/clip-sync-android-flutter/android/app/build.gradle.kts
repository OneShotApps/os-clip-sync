import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyFile = rootProject.file("key.properties")
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseBuildRequested && !releaseKeyFile.isFile) {
    throw GradleException(
        "Android release signing is required. Create excluded android/key.properties as documented in README.md.",
    )
}
val releaseKeys = Properties()
if (releaseKeyFile.isFile) {
    releaseKeyFile.inputStream().use(releaseKeys::load)
}

android {
    namespace = "app.oneshot.clipsync.clip_sync_android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.oneshot.clipsync.clip_sync_android"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeyFile.isFile) {
            create("release") {
                fun required(name: String): String =
                    releaseKeys.getProperty(name)?.takeIf { it.isNotBlank() }
                        ?: throw GradleException("android/key.properties is missing $name.")

                storeFile = file(required("storeFile"))
                storePassword = required("storePassword")
                keyAlias = required("keyAlias")
                keyPassword = required("keyPassword")
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
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
