import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// M4: load the Google Maps native SDK key from android/secrets.properties IF present.
// The file is git-ignored; when absent, MAPS_API_KEY defaults to "" so the app builds
// "dark" (no key → google_maps_flutter renders nothing, and googleNavEnabled is false).
val secretsProperties = Properties().apply {
    val f = rootProject.file("secrets.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

// Release signing credentials, from the git-ignored android/key.properties (see
// key.properties.sample). Presence of the FILE proves nothing — a half-filled
// key.properties is how a release gets signed with the wrong identity — so all
// four properties must be non-blank.
val keyProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val releaseSigningReady = listOf(
    "storeFile", "storePassword", "keyAlias", "keyPassword",
).all { !keyProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "au.edu.mq.astronomy.aon2026"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "au.edu.mq.astronomy.aon2026"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Substituted into AndroidManifest's com.google.android.geo.API_KEY meta-data.
        // Empty when secrets.properties is absent → build stays green, feature stays dark.
        manifestPlaceholders["MAPS_API_KEY"] = secretsProperties.getProperty("MAPS_API_KEY", "")
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Only wired when credentials exist. When they do not, the task-graph
            // check below stops the build before anything is produced — throwing
            // HERE would run at configuration time and break debug builds too.
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// FAIL CLOSED, at execution time and for release tasks only.
//
// A debug-signed "release" is worse than no build at all: it looks shippable, it
// uploads, and then every Google Maps key restriction rejects it for every real
// user, because the signing certificate is not one Play distributes under.
//
// This lives in the task graph rather than inside `buildTypes { release { } }`
// because that block is evaluated at CONFIGURATION time — throwing there fails
// `flutter build apk --debug` and `flutter run` as well, which is how the first
// attempt at this broke every build in the repo.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        task.name.contains("Release") &&
            listOf("assemble", "bundle", "package").any { task.name.startsWith(it) }
    }
    if (buildingRelease && !releaseSigningReady) {
        throw GradleException(
            "Release signing is not configured. Copy android/key.properties.sample " +
                "to android/key.properties and fill storeFile, storePassword, " +
                "keyAlias and keyPassword. Debug signing is never used for release.",
        )
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
