plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.android.krama"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.android.krama"
        minSdk = 26
        targetSdk = 36
        versionCode = 3
        versionName = "2.0.1"
    }

    signingConfigs {
        create("release") {
            storeFile = file("C:\\Users\\surya\\.android\\krama-release.jks")
            storePassword = "Suryach_07"
            keyAlias = "krama"
            keyPassword = "Suryach_07"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.core:core-ktx:1.12.0")
}