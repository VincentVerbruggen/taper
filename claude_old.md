# Taper - Android App

## Project Overview
A native Android app built with Kotlin and Jetpack Compose. The developer is a PHP/web developer (8 YOE) learning Android — always include explanatory comments in code changes explaining how/why things work.

## Tech Stack
- **Language:** Kotlin
- **UI Framework:** Jetpack Compose (declarative UI, no XML layouts)
- **Design System:** Material 3 (Material You)
- **Build System:** Gradle with Kotlin DSL (`.kts` files)
- **Min SDK:** 26 (Android 8.0) | **Target/Compile SDK:** 36

## Project Structure
```
app/src/main/java/com/vincent/taper/
├── MainActivity.kt              # App entry point + navigation scaffold
└── ui/theme/
    ├── Theme.kt                 # Material 3 theme (dark/light, dynamic colors)
    ├── Color.kt                 # Color palette
    └── Type.kt                  # Typography
```

## Key Files
- `app/build.gradle.kts` — App dependencies and build config (like composer.json)
- `gradle/libs.versions.toml` — Centralized dependency versions (like a lockfile)
- `app/src/main/AndroidManifest.xml` — App manifest, declares activities and permissions
- `app/src/main/res/values/strings.xml` — String resources (like lang files)

## Collaboration Style
- **Small steps** — Make changes incrementally so the developer can follow along
- **Comments everywhere** — Focus on the HOW and WHY, not WHAT the code does (the dev can read code fine)
- **Ask questions aggressively** — Use AskUserQuestion tool liberally to clarify before building
- **Plans as markdown** — When planning a feature, create a markdown file in the repo (e.g. `plans/feature-name.md`) with the plan, filled with how/why explanations
- **PHP/Laravel analogies** — Explain Android concepts by comparing to PHP/Laravel/web dev equivalents
- Package name: `com.vincent.taper`

## Conventions
- Use Jetpack Compose for all UI (no XML layouts)
- Follow Material 3 design guidelines
- Use Kotlin idioms (data classes, sealed classes, extension functions, coroutines)

## Build & Run
- Open in Android Studio and run on emulator/device
- CLI build: `./gradlew assembleDebug`
- CLI tests: `./gradlew test` (unit) / `./gradlew connectedAndroidTest` (instrumented)

