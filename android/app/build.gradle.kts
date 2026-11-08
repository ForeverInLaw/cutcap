plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.foreverinlaw.cutcap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.foreverinlaw.cutcap"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 10: the lowest version cutcap supports (docs/SPEC.md).
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        getByName("debug") {
            // CI signs every debug APK with one cached key so each installs
            // over the last; locally the SDK's own debug key is used.
            System.getenv("CUTCAP_DEBUG_KEYSTORE")?.let { storeFile = file(it) }
        }
        // The persistent release key. CI decodes the ANDROID_KEYSTORE_BASE64
        // secret into the file at ANDROID_KEYSTORE_PATH and passes the other
        // three secrets through (docs/android-release.md).
        System.getenv("ANDROID_KEYSTORE_PATH")?.let { keystore ->
            create("release") {
                fun secret(name: String) = requireNotNull(System.getenv(name)) { "$name is not set" }
                storeFile = file(keystore)
                storePassword = secret("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = secret("ANDROID_KEY_ALIAS")
                keyPassword = secret("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Without the release key (local builds) the debug key signs, so
            // `flutter run --release` works; CI refuses to publish such an APK.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
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
    // Export (Media3Export.kt): Transformer brings the effect, muxer and
    // ExoPlayer modules it needs.
    implementation("androidx.media3:media3-transformer:1.11.1")
    implementation("androidx.media3:media3-effect:1.11.1")
    implementation("androidx.media3:media3-common:1.11.1")
    // Kotlin unit tests (`./gradlew :app:testDebugUnitTest`), run in CI.
    testImplementation("junit:junit:4.13.2")
}
