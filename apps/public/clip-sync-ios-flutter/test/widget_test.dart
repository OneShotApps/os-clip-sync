import 'package:clip_sync_client_core/clip_sync_client_core.dart';
import 'package:clip_sync_ios/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows startup progress before controller initialization', (
    tester,
  ) async {
    final sessionStore = SessionStore();
    final controller = ClipSyncController(
      apiClient: ClipSyncApiClient(baseUrl: 'http://127.0.0.1:4100'),
      sessionStore: sessionStore,
      googleAuthService: GoogleAuthService(sessionStore: sessionStore),
      clipboard: ClipboardAdapter(),
      shareReceiver: ShareReceiver(),
      platform: 'ios',
      isDesktop: false,
    );

    await tester.pumpWidget(
      ClipSyncMobileApp(controller: controller, platformName: 'iOS'),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
