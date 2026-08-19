import 'package:clip_sync_android/main.dart';
import 'package:clip_sync_client_core/clip_sync_client_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows startup progress before controller initialization', (
    tester,
  ) async {
    final sessionStore = SessionStore();
    final controller = ClipSyncController(
      apiClient: ClipSyncApiClient(baseUrl: 'http://10.0.2.2:4200'),
      sessionStore: sessionStore,
      googleAuthService: GoogleAuthService(sessionStore: sessionStore),
      clipboard: ClipboardAdapter(),
      shareReceiver: ShareReceiver(),
      deviceNameProvider: DeviceNameProvider(),
      platform: 'android',
      isDesktop: false,
    );

    await tester.pumpWidget(
      ClipSyncMobileApp(controller: controller, platformName: 'Android'),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
