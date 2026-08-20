# Clip Sync for Android

This target-specific Flutter application browses, copies, refreshes, and deletes private history. Tap the leading content icon on one or more history rows to select them, then use Delete selected and confirm to remove them. Its Devices control lists and renames account-owned devices, and history shows the current source-device name. Android's share sheet can send text or photos to Clip Sync. It never monitors or automatically changes the mobile clipboard.

While clipboard history is visible, the app refreshes every 5 seconds for 30 seconds, then every 30 seconds. Automatic refresh pauses after 2 minutes and displays a notice. Press the refresh button or pull down on the history list to refresh immediately and restart the schedule. Leaving the app stops the schedule until the app is visible again.

Install Flutter 3.47, Android SDK Build-Tools and Android Native Development Kit (NDK) r28 or newer, and Rust through the official [`rustup`](https://rustup.rs/) installer. Cargokit requires Rust's stable channel; the current build is validated with Rust 1.97.1:

```sh
rustup toolchain install stable --profile minimal
rustup default stable
```

The committed `cargokit_options.yaml` forces the stable clipboard plugin's Rust library to compile with the app's Android NDK. Do not remove it or enable the plugin's upstream precompiled binary: that binary is aligned only for 4 KB memory pages and makes the application rely on Android compatibility mode.

```sh
flutter pub get
flutter analyze
flutter test
node ../../../tools/with-google-oauth.js -- flutter run
node ../../../tools/with-google-oauth.js -- flutter build apk --release --dart-define=CLIP_SYNC_API_URL=https://api.example.com
./tool/check-16kb-alignment.sh build/app/outputs/flutter-apk/app-release.apk
```

The alignment check validates every packaged ARM64 and x86-64 native library plus the APK's ZIP alignment. It requires `unzip`, Android SDK Build-Tools, and the Android NDK. A release is not valid if any library reports `UNALIGNED`.

The Android emulator reaches a host-local API through `10.0.2.2`; physical devices need a reachable HTTPS address. The manifest registers `ACTION_SEND` for `text/plain` and `image/*` and the provider required by the clipboard plugin.

Release builds must be signed with a deployment-owned key. Create the excluded `android/key.properties` file and point `storeFile` at a keystore outside source control:

```properties
storeFile=/secure/path/clip-sync-upload.jks
storePassword=provided-by-secret-environment
keyAlias=clip-sync
keyPassword=provided-by-secret-environment
```

The build fails clearly when release signing is missing; it never falls back to the public debug key.

The launcher supplies the committed web client ID used as the Google server client ID. Google sign-in also requires an Android client registered for application ID `app.oneshot.clipsync.clip_sync_android` and each signing certificate used by the installed build. Email-code sign-in requires no Google client.
