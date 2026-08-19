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
      apiClient: ClipSyncApiClient(baseUrl: 'http://127.0.0.1:4200'),
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

  testWidgets('refresh button reloads clipboard history', (tester) async {
    final sessionStore = _FakeSessionStore();
    final apiClient = _FakeApiClient();
    final controller = ClipSyncController(
      apiClient: apiClient,
      sessionStore: sessionStore,
      googleAuthService: GoogleAuthService(sessionStore: sessionStore),
      clipboard: ClipboardAdapter(),
      shareReceiver: _FakeShareReceiver(),
      platform: 'ios',
      isDesktop: false,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      ClipSyncMobileApp(controller: controller, platformName: 'iOS'),
    );
    expect(find.byTooltip('Refresh history'), findsOneWidget);
    expect(apiClient.historyRequestCount, 1);

    await tester.tap(find.byTooltip('Refresh history'));
    await tester.pumpAndSettle();

    expect(apiClient.historyRequestCount, 2);
  });
}

class _FakeSessionStore extends SessionStore {
  final AuthSession _session = AuthSession(
    accessToken: 'token',
    expiresAt: DateTime.utc(2099),
    accountUid: 'A' * 32,
    email: 'person@example.com',
    clipboardUid: 'B' * 32,
  );

  @override
  Future<String> readOrCreateClientUid() async => 'C' * 32;

  @override
  Future<AuthSession?> readSession() async => _session;
}

class _FakeApiClient extends ClipSyncApiClient {
  _FakeApiClient() : super(baseUrl: 'http://example.test');

  int historyRequestCount = 0;

  @override
  Future<ClipItemPage> listHistory(
    AuthSession session, {
    required int page,
    int pageSize = 50,
  }) async {
    historyRequestCount += 1;
    return const ClipItemPage(items: [], page: 1, totalPages: 1);
  }
}

class _FakeShareReceiver extends ShareReceiver {
  @override
  Future<void> initialize() async {}
}
