# Clip Sync for Android

This target-specific Flutter application browses, copies, refreshes, and deletes private history. Android's share sheet can send text or photos to Clip Sync. It never monitors or automatically changes the mobile clipboard.

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=CLIP_SYNC_API_URL=http://10.0.2.2:4100
flutter build apk --release --dart-define=CLIP_SYNC_API_URL=https://api.example.com
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

For Google sign-in, configure a Google Android client for application ID `app.oneshot.clipsync.clip_sync_android` and its signing certificate. Email-code sign-in requires no Google client.
