import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release signing ────────────────────────────────────────────────────────────────────
// The key and its passwords live in `android/key.properties` + a `.jks`, and NEITHER is in
// git (`android/.gitignore` and the root `.gitignore` both exclude them).
//
// Without that file a release build is REFUSED rather than silently signed with the debug
// key. The debug key is how every build up to now went out, and an APK signed with it can
// never be upgraded by a properly signed one — so a shop would have to uninstall. A Gradle
// warning is not enough of a guard: `flutter build apk` prints its own two lines and
// swallows Gradle's, which is exactly when a warning would have been needed.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else if (!project.hasProperty("allowDebugSigning")) {
    error("android/key.properties not found: refusing to build a release APK signed with the debug key (it can never be upgraded by a properly signed one). Run scripts/create_release_key.ps1 once and build again - see RELEASE.md. For a throwaway test APK use `flutter build apk --debug`, or pass -PallowDebugSigning=true to Gradle directly (RELEASE.md says how).")
}

// A missing or blank entry is a mistake worth naming plainly.
fun requiredSigningProperty(name: String): String =
    keystoreProperties.getProperty(name)
        ?.takeIf { it.isNotBlank() }
        ?: error("android/key.properties has no $name — see android/key.properties.example")

android {
    namespace = "com.example.drinks_calculator_fixed"
    // Plugins (app_links, flutter_tts, local_auth, etc.) require compileSdk 36.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_local_notifications needs core library desugaring for
        // java.time APIs on older Android versions.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.drinks_calculator_fixed"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = requiredSigningProperty("keyAlias")
                keyPassword = requiredSigningProperty("keyPassword")
                storeFile = file(requiredSigningProperty("storeFile"))
                storePassword = requiredSigningProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // The real key whenever key.properties is present. The debug key is reachable
            // only through the explicit -PallowDebugSigning=true escape hatch above.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications for core library desugaring.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}
