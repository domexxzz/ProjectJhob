allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// บาง plugin (เช่น flutter_facebook_auth 6.x) ตั้ง Java=11 เองแต่ปล่อย Kotlin
// ตาม JDK ในเครื่อง (21) → Gradle รุ่นใหม่ error "Inconsistent JVM-target".
// บังคับทุกโมดูลให้ Java=17 + Kotlin=17 เท่ากัน (แก้ที่ root เพราะแก้โค้ด plugin ไม่ได้)
subprojects {
    // บาง plugin (เช่น flutter_facebook_auth 6.x) ตั้ง Java=11 แต่ปล่อย Kotlin
    // ตาม JDK ในเครื่อง (21) → บังคับ Kotlin=17 ให้ bytecode ไม่สูงเกินที่ D8 dex ได้
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    // ปลั๊กอินเก่าตั้ง compileSdk=31 / Java=11 เอง แต่ AndroidX ยุคใหม่ต้อง compileSdk 36
    // (androidx.navigationevent) → ทับด้วย compileSdk=36 (ตรงกับ app) + Java=17
    // ผ่าน afterEvaluate (รันก่อน AGP ล็อก DSL) ใช้ dynamic dispatch เลี่ยง generic ของ AGP DSL
    // ข้าม project ที่ evaluate ไปแล้ว (:app ถูก force โดย evaluationDependsOn) กัน error "finalized"
    if (!state.executed) {
        afterEvaluate {
            extensions.findByName("android")?.withGroovyBuilder {
                setProperty("compileSdk", 36)
                "compileOptions" {
                    setProperty("sourceCompatibility", JavaVersion.VERSION_17)
                    setProperty("targetCompatibility", JavaVersion.VERSION_17)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
