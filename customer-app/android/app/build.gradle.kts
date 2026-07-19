import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use(keyProperties::load)
fun signingValue(property: String, environment: String): String? =
    keyProperties.getProperty(property) ?: System.getenv(environment)

android {
    namespace = "com.delivery.platform.customer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }

    defaultConfig {
        applicationId = "com.delivery.platform.customer"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "app_name", "Delivery")
    }

    signingConfigs {
        create("release") {
            val storePath=signingValue("storeFile","DELIVERY_ANDROID_STORE_FILE")
            if (storePath!=null) storeFile=file(storePath)
            storePassword=signingValue("storePassword","DELIVERY_ANDROID_STORE_PASSWORD")
            keyAlias=signingValue("keyAlias","DELIVERY_ANDROID_KEY_ALIAS")
            keyPassword=signingValue("keyPassword","DELIVERY_ANDROID_KEY_PASSWORD")
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            resValue("string", "app_name", "Delivery Debug")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter { source = "../.." }
