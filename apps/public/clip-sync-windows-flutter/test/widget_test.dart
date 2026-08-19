import 'package:clip_sync_client_core/clip_sync_client_core.dart';
import 'package:clip_sync_windows/src/clip_sync_app.dart';
import 'package:flutter/material.dart';
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
      platform: 'windows',
      isDesktop: true,
    );

    await tester.pumpWidget(ClipSyncApp(controller: controller));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
