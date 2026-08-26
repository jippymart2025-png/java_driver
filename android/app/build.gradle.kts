import java.util.Properties
import java.io.FileInputStream

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jippymart.driver"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jippymart.driver"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }



//            signingConfigs {
//                create("release") {

                    // keyAlias = keystoreProperties["keyAlias"] as String
                    // keyPassword = keystoreProperties["keyPassword"] as String
                    // storeFile = file(keystoreProperties["storeFile"] as String
                    // storePassword = keystoreProperties["storePassword"] as String

//                    keyAlias = keystoreProperties["keyAlias"]?.toString() ?: ""
//                    keyPassword = keystoreProperties["keyPassword"]?.toString() ?: ""
//                    storeFile = file(keystoreProperties["storeFile"]?.toString() ?: "")
//                    storePassword = keystoreProperties["storePassword"]?.toString() ?: ""
//                }
//            }

    signingConfigs {
        create("release") {

            if (keystorePropertiesFile.exists()) {

                keyAlias = keystoreProperties["keyAlias"]?.toString()
                keyPassword = keystoreProperties["keyPassword"]?.toString()

                val storeFilePath = keystoreProperties["storeFile"]?.toString()

                if (storeFilePath != null) {
                    storeFile = file(storeFilePath)
                }

                storePassword = keystoreProperties["storePassword"]?.toString()
            }
        }
    }




    buildTypes {
        getByName("release") {
            // signingConfig = signingConfigs.getByName("release")
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
//    signingConfigs {
//        release {
//            keyAlias keystoreProperties['keyAlias']
//            keyPassword keystoreProperties['keyPassword']
//            storeFile file(keystoreProperties['storeFile'])
//            storePassword keystoreProperties['storePassword']
//        }
//    }
//    buildTypes {
//        release {
//            signingConfig signingConfigs.release
//                    minifyEnabled true
//            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
//        }
////        release {
////            // TODO: Add your own signing config for the release build.
////            // Signing with the debug keys for now, so `flutter run --release` works.
////            signingConfig = signingConfigs.getByName("debug")
////        }
//    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
//    implementation("com.google.android.material:material:1.12.0")
    implementation("com.google.android.material:material:1.9.0")
    // your other dependencies...
}

//dependencies {
////    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.3'
//    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
//    implementation 'com.google.android.material:material:1.9.0'
//    implementation "org.jetbrains.kotlin:kotlin-stdlib:$kotlin_version"
//    implementation platform('com.google.firebase:firebase-bom:33.15.0')
//    implementation 'io.card:android-sdk:5.5.1'
//    implementation 'com.tencent.mm.opensdk:wechat-sdk-android-without-mta:6.7.0'
//    implementation 'com.google.android.gms:play-services-wallet:19.5.0'
//    implementation 'androidx.multidex:multidex:2.0.1'
//    implementation 'com.google.firebase:firebase-analytics'
//    implementation 'com.google.android.play:integrity:1.4.0'
//
//    // Graphics optimization
//    implementation 'androidx.core:core:1.10.0'
//    implementation 'androidx.window:window:1.0.0'
//
//    configurations.all {
//        resolutionStrategy {
//            force "org.jetbrains.kotlin:kotlin-stdlib:$kotlin_version"
//            force "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
//            force "org.jetbrains.kotlin:kotlin-stdlib-jdk8:$kotlin_version"
//            force "org.jetbrains.kotlin:kotlin-stdlib-common:$kotlin_version"
//            force "org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3"
//            force "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"
//            force "org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3"
////            force "org.jetbrains.kotlinx:kotlinx-coroutines-core:1.6.4"
////            force "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.6.4"
////            force "org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.6.4"
//        }
//    }
//}

flutter {
    source = "../.."
}
