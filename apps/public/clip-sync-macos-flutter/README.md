# Clip Sync for macOS

This resident target-specific Flutter application monitors text and photos while active, receives live items into the clipboard, offers history/copy/delete, and exposes Pause, Show, and Quit in the menu bar. Click the leading content icon on one or more history rows to select them, then use Delete selected and confirm to remove them. It registers the Mac's operating-system computer name, displays current source-device names in history, and can rename any account-owned device from the Devices control. Closing the window keeps the user-level process running.

While the clipboard-history window is visible, history refreshes every 5 seconds for 30 seconds, then every 30 seconds. Automatic refresh pauses after 2 minutes and displays a notice. Press Refresh to refresh immediately and restart the schedule. Hiding or minimizing the window stops the schedule until the window is shown again.

```sh
flutter pub get
flutter analyze
flutter test
node ../../../tools/with-google-oauth.js -- flutter run -d macos
node ../../../tools/with-google-oauth.js -- flutter build macos --release --dart-define=CLIP_SYNC_API_URL=https://api.example.com
```

The native `NSServices` entry accepts selected text and image/file URLs from macOS Services and forwards them through the shared client controller. Enable Clip Sync in System Settings > Keyboard > Keyboard Shortcuts > Services if macOS does not show it immediately.

A complete Xcode installation and CocoaPods are required to build. The launcher supplies the Google client values and redirect port required by `google_sign_in_all_platforms`. The Google client must retain exact `http://localhost:8000` origin and redirect entries. Both macOS entitlement profiles allow the sandboxed app to open that local callback listener. Email-code sign-in remains available without Google.

The first Flutter frame does not wait for menu-bar initialization. The menu-bar icon is a declared Flutter asset, and a tray failure is reported to the launch terminal without leaving an empty native window.

Signed builds store session values in the macOS Keychain. An ad-hoc-signed local build cannot claim the Keychain access-group entitlement, so it falls back to process memory if Keychain access is denied. Tokens remain off disk, but you must sign in again after restarting that local build.
