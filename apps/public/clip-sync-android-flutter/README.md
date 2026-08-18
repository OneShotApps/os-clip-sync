# Clip Sync for Android

This target-specific Flutter application browses, copies, refreshes, and deletes private history. Android's share sheet can send text or photos to Clip Sync. It never monitors or automatically changes the mobile clipboard.

```sh
flutter pub get
flutter analyze
flutter test
node ../../../tools/with-google-oauth.js -- flutter run --dart-define=CLIP_SYNC_API_URL=http://10.0.2.2:4100
node ../../../tools/with-google-oauth.js -- flutter build apk --release --dart-define=CLIP_SYNC_API_URL=https://api.example.com
```

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
