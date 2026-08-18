# Clip Sync client core

This private Flutter package contains only behavior shared by the four delivered clients: typed API calls, secure session storage, Google sign-in, text/photo clipboard access, operating-system share intake, presentation state, and desktop polling/WebSocket synchronization.

It is intentionally not a reusable framework. Platform presentation and native tray, menu, and share-target resources remain inside each application.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

`ClipSyncController` is the UI-facing state boundary. `DesktopSyncController` is instantiated only by Windows and macOS clients; iOS and Android never monitor or automatically update their clipboards. The package stores only authentication state, a random client UID, and the Google access token in operating-system secure storage. It does not persist clipboard content or history.
