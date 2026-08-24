plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.alatyr.starter"
    // flutter_secure_storage 11 ships AAR metadata requiring compileSdk 37;
    // Flutter 3.44.9 defaults to 36 (flutter.compileSdkVersion). See
    // docs/workflow/maintenance.md.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.alatyr.starter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Patrol e2e (tool/e2e.sh). The orchestrator (testOptions below) runs
        // every Dart test in its own process. That process boundary is NOT
        // what the registered critical flow calls a "restart": that flow
        // re-invokes the app entrypoint within a single test (spec section 8's
        // convention, docs/reference/critical_flows.md). The boundary is what
        // the second, bonus test in integration_test/settings_theme_test.dart
        // spends to prove real OS process death. Patrol's docs also set
        // testInstrumentationRunnerArguments["clearPackageData"] = "true" -
        // deliberately NOT here: it would wipe app data between the tests and
        // with it the persisted state that bonus test reads.
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
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
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
