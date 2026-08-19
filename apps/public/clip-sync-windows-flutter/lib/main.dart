import 'dart:async';

import 'package:clip_sync_client_core/clip_sync_client_core.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/clip_sync_app.dart';
import 'src/resident_desktop.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(900, 680),
    minimumSize: Size(720, 540),
    center: true,
    title: 'Clip Sync',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  const apiUrl = String.fromEnvironment(
    'CLIP_SYNC_API_URL',
    defaultValue: 'http://127.0.0.1:4200',
  );
  final sessionStore = SessionStore();
  final controller = ClipSyncController(
    apiClient: ClipSyncApiClient(baseUrl: apiUrl),
    sessionStore: sessionStore,
    googleAuthService: GoogleAuthService(sessionStore: sessionStore),
    clipboard: ClipboardAdapter(),
    shareReceiver: ShareReceiver(),
    platform: 'windows',
    isDesktop: true,
  );
  final residentDesktop = ResidentDesktop(controller);
  await residentDesktop.initialize();

  runApp(ClipSyncApp(controller: controller));
  unawaited(controller.initialize());
}
