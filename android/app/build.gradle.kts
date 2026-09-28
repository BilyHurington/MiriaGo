import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file(
    providers.gradleProperty("releaseSigningPropertiesFile").orElse("key.properties").get()
)
if (keystorePropertiesFile.isFile) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val releaseKeystoreFile = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }?.let { file(it) }
val missingSigningProperties = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
val verifyReleaseSigning = tasks.register("verifyReleaseSigningConfiguration") {
    group = "verification"
    description = "Require explicit signing credentials for release builds."
    doLast {
        if (!keystorePropertiesFile.isFile) {
            throw GradleException("Release signing configuration is missing. Provide key.properties; debug signing is never used for release.")
        }
        if (missingSigningProperties.isNotEmpty()) {
            throw GradleException("Release signing configuration is incomplete: ${missingSigningProperties.joinToString()}. No debug signing fallback is allowed.")
        }
        if (releaseKeystoreFile?.isFile != true || !releaseKeystoreFile.canRead()) {
            throw GradleException("Release keystore is missing or unreadable. Restore the existing release keystore; do not replace it with a debug key.")
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" || it.name == "validateSigningRelease" }
    .configureEach { dependsOn(verifyReleaseSigning) }

android {
    namespace = "app.miriago.miriago"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.miriago.miriago"
        // Opt-in side-by-side install (e.g. -PmiriagoApplicationIdSuffix=.next
        // or ORG_GRADLE_PROJECT_miriagoApplicationIdSuffix=.next). Default
        // builds keep the original id so they upgrade the installed app.
        val idSuffix = providers.gradleProperty("miriagoApplicationIdSuffix")
            .orElse("").get()
        if (idSuffix.isNotBlank()) applicationIdSuffix = idSuffix
        manifestPlaceholders["appLabel"] = providers.gradleProperty("miriagoAppLabel")
            .orElse("MiriaGo").get()
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = releaseKeystoreFile
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
    val cameraxVersion = "1.5.1"
    implementation("androidx.camera:camera-core:$cameraxVersion")
    implementation("androidx.camera:camera-camera2:$cameraxVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraxVersion")
    implementation("androidx.camera:camera-view:$cameraxVersion")
    implementation("androidx.exifinterface:exifinterface:1.4.1")
}
