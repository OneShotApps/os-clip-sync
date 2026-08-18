# Clip Sync for macOS

This resident target-specific Flutter application monitors text and photos while active, receives live items into the clipboard, offers history/copy/delete, and exposes Pause, Show, and Quit in the menu bar. Closing the window keeps the user-level process running.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d macos --dart-define=CLIP_SYNC_API_URL=http://localhost:4100
flutter build macos --release --dart-define=CLIP_SYNC_API_URL=https://api.example.com
```

The native `NSServices` entry accepts selected text and image/file URLs from macOS Services and forwards them through the shared client controller. Enable Clip Sync in System Settings > Keyboard > Keyboard Shortcuts > Services if macOS does not show it immediately.

A complete Xcode installation and CocoaPods are required to build. Configure the macOS Google client values required by `google_sign_in_all_platforms`; email-code sign-in remains available without Google.
