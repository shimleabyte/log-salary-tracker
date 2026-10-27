# Android ABI filter (ARM 32-bit only)

Add the following snippet to the existing `android { defaultConfig { ... } }` section in `android/app/build.gradle`:

```gradle
ndk {
    abiFilters.clear()
    abiFilters.addAll(["armeabi-v7a"])
}
```

Then build with:

```bash
flutter build apk --release --target-platform android-arm
```

Inspect the APK and confirm it contains `lib/armeabi-v7a/` and does not contain `lib/arm64-v8a/`.
