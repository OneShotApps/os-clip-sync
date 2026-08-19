# Clip Sync for iOS

This target-specific Flutter application browses, copies, refreshes, and deletes private history. Its native Share Extension accepts text and photos. It never monitors or automatically changes the mobile clipboard.

While clipboard history is visible, the app refreshes every 5 seconds for 30 seconds, then every 30 seconds. Automatic refresh pauses after 2 minutes and displays a notice. Press the refresh button or pull down on the history list to refresh immediately and restart the schedule.

```sh
flutter pub get
flutter analyze
flutter test
GEM_HOME="$(brew --prefix cocoapods)/libexec" ruby tool/configure-share-extension.rb
node ../../../tools/with-google-oauth.js -- flutter build ios --release --no-codesign --dart-define=CLIP_SYNC_API_URL=https://api.example.com
```

The repeatable Ruby tool creates or refreshes the `ShareExtension` Xcode target and shared App Group settings. Run it after regenerating iOS project files. Register `group.app.oneshot.clipsync.clipSyncIos` (or replace it consistently in both targets) and configure the deployment signing team, then enable that App Group for both targets in Apple Developer. A complete Xcode installation and CocoaPods are required for a native build.

The extension uses its own Xcode `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` settings. Keep those values aligned with the app version in `pubspec.yaml`; undefined Flutter build variables are removed from an extension's processed property list and prevent Simulator installation.

The launcher supplies the committed web client ID used as the Google server client ID. Google sign-in also requires an iOS client for bundle ID `app.oneshot.clipsync.clipSyncIos` and the matching URL-scheme configuration required by `google_sign_in_all_platforms`. Email-code sign-in requires no Google client.
