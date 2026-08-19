import 'dart:io';

import 'package:clip_sync_client_core/clip_sync_client_core.dart';
import 'package:clip_sync_macos/src/clip_sync_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows startup progress before controller initialization', (
    tester,
  ) async {
    final sessionStore = SessionStore();
    final controller = ClipSyncController(
      apiClient: ClipSyncApiClient(baseUrl: 'http://127.0.0.1:4200'),
      sessionStore: sessionStore,
      googleAuthService: GoogleAuthService(sessionStore: sessionStore),
      clipboard: ClipboardAdapter(),
      shareReceiver: ShareReceiver(),
      platform: 'macos',
      isDesktop: true,
    );

    await tester.pumpWidget(ClipSyncApp(controller: controller));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('bundles the macOS menu bar icon', (tester) async {
    final icon = await rootBundle.load(
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png',
    );

    expect(icon.lengthInBytes, greaterThan(0));
  });

  test('release permits the local Google OAuth callback listener', () {
    final entitlements = File('macos/Runner/Release.entitlements')
        .readAsStringSync();

    expect(
      entitlements,
      matches(
        RegExp(r'<key>com\.apple\.security\.network\.server</key>\s*<true/>'),
      ),
    );
  });
}
