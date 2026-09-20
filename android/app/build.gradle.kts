import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseProperties = Properties()
val releasePropertiesFile = rootProject.file("key.properties")
if (releasePropertiesFile.exists()) {
    releasePropertiesFile.inputStream().use { releaseProperties.load(it) }
}
fun signingValue(name: String, environment: String): String? =
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: releaseProperties.getProperty(name)?.takeIf { it.isNotBlank() }

val releaseStore = signingValue("storeFile", "LEXHUB_ANDROID_STORE_FILE")
val releaseStorePassword = signingValue("storePassword", "LEXHUB_ANDROID_STORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "LEXHUB_ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "LEXHUB_ANDROID_KEY_PASSWORD")
val releaseSigningReady = listOf(
    releaseStore, releaseStorePassword, releaseKeyAlias, releaseKeyPassword
).all { it != null }

// Fail closed: a release must never silently inherit debug signing.
gradle.taskGraph.whenReady {
    val createsRelease = allTasks.any {
        it.project.path == project.path &&
            it.name in listOf("assembleRelease", "bundleRelease", "packageRelease")
    }
    if (createsRelease) {
        check(releaseSigningReady) {
            "Release signing is required. Configure android/key.properties or LEXHUB_ANDROID_* signing variables."
        }
        check(!releaseKeyAlias.equals("androiddebugkey", ignoreCase = true) &&
            !releaseStore.orEmpty().replace('\\', '/').substringAfterLast('/')
                .equals("debug.keystore", ignoreCase = true)) {
            "Debug signing is not permitted for release artifacts."
        }
    }
}

android {
    namespace = "com.lexhub.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lexhub.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                storeFile = rootProject.file(requireNotNull(releaseStore))
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
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
