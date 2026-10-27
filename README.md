# Teacher Log & Salary Tracker

A lightweight Flutter app for recording teaching sessions and estimating monthly pay. The interface uses a soft teal/green palette and is designed for mobile screens and modest Android hardware.

## Features

- Record the lesson date, class name, number of JP, and Tahsin/Tahfidz notes.
- Browse a monthly summary and switch between months.
- Calculate total JP, unique attendance days, base honor, daily transport, and estimated take-home pay.
- Edit the honor-per-JP and transport-per-day rates.
- Persist logs and rates locally with `shared_preferences`.
- Delete an individual log entry.

Default rates: Rp20,000 per JP and Rp25,000 per unique attendance day. THP is an estimate and does not account for other deductions.

## Requirements

- Flutter SDK with Dart 3.4 or newer.
- Android `minSdk` 24 or newer (required by the selected `shared_preferences` release).

## Set up the Android project

This repository contains the app source and configuration notes. Generate the platform boilerplate with Flutter in this directory:

```bash
flutter create --platforms=android --project-name teacher_log_salary_tracker .
flutter pub get
```

If Flutter reports that the directory already contains project files, preserve `lib/main.dart` and `pubspec.yaml`, and generate the Android platform files in a fresh Flutter project before copying these two files over.

## ARM 32-bit only

Open `android/app/build.gradle` and place this inside the existing `android { defaultConfig { ... } }` block. Do not create a duplicate `android` or `defaultConfig` block.

```gradle
ndk {
    abiFilters.clear()
    abiFilters.addAll(["armeabi-v7a"])
}
```

Keep the app's `minSdk` at 24 or higher. Build an ARM 32-bit release APK with:

```bash
flutter build apk --release --target-platform android-arm
```

Expected output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Verify the artifact before distribution. It should contain `lib/armeabi-v7a/` and should not contain `lib/arm64-v8a/`. This package intentionally does not target 64-bit ARM devices that only accept 64-bit apps.

## Data storage note

The app stores data on the device using `SharedPreferencesAsync`. It is not cloud-synced and app uninstall/data clearing may remove its records. Export/backup is not currently implemented.

## Validation status

The Flutter SDK was not available in the authoring environment, so `flutter analyze` and a release APK build have not been run. Run both locally before distributing:

```bash
flutter analyze
flutter build apk --release --target-platform android-arm
```