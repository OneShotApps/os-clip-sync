# Clip Sync for Windows 11

This resident target-specific Flutter application monitors text and photos while active, receives live items into the clipboard, offers history/copy/delete, and exposes Pause, Show, and Quit in the system tray. It registers the Windows computer name, displays current source-device names in history, and can rename any account-owned device from the Devices control. Closing the window keeps the user-level process running.

Build on Windows 11 with Flutter, Visual Studio's Desktop C++ workload, the Universal Windows Platform workload, and MSBuild:

```powershell
flutter pub get
flutter analyze
flutter test
node ..\..\..\tools\with-google-oauth.js -- flutter build windows --release --dart-define=CLIP_SYNC_API_URL=https://api.example.com
msbuild windows\packaging\Package.wapproj /p:Configuration=Release /p:Platform=x64
```

The MSIX packaging project combines the full-trust Flutter executable with a small UWP share-target process. The share target accepts text, bitmaps, and image files, writes one pending item into app-local storage, and launches the `clipsync-share` protocol so the Flutter process uploads it. Sign the resulting MSIX with a trusted deployment certificate before distribution.

The launcher supplies the Google client values and redirect port required by `google_sign_in_all_platforms`. The Google client must retain exact `http://localhost:8000` origin and redirect entries. Email-code sign-in remains available without Google.
