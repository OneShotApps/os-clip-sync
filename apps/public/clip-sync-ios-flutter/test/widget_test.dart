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
      deviceNameProvider: DeviceNameProvider(),
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
      deviceNameProvider: _FakeDeviceNameProvider(),
      platform: 'ios',
      isDesktop: false,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      ClipSyncMobileApp(controller: controller, platformName: 'iOS'),
    );
    expect(find.byTooltip('Refresh history'), findsOneWidget);
    expect(find.byTooltip('Manage devices'), findsOneWidget);
    expect(apiClient.historyRequestCount, 1);

    await tester.tap(find.byTooltip('Refresh history'));
    await tester.pumpAndSettle();

    expect(apiClient.historyRequestCount, 2);

    await tester.tap(find.byTooltip('Manage devices'));
    await tester.pumpAndSettle();
    expect(find.text('Other Mac'), findsOneWidget);

    await tester.tap(find.byTooltip('Rename Other Mac'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Home Mac');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Home Mac'), findsOneWidget);
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
  Future<SyncDevice> registerDevice({
    required AuthSession session,
    required String clientUid,
    required String platform,
    required String name,
  }) async => SyncDevice(uid: clientUid, name: name, platform: platform);

  @override
  Future<List<SyncDevice>> listDevices(AuthSession session) async => [
    SyncDevice(uid: 'C' * 32, name: 'Test iPhone', platform: 'ios'),
    SyncDevice(uid: 'D' * 32, name: 'Other Mac', platform: 'macos'),
  ];

  @override
  Future<SyncDevice> renameDevice({
    required AuthSession session,
    required String deviceUid,
    required String name,
  }) async => SyncDevice(uid: deviceUid, name: name, platform: 'macos');

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

class _FakeDeviceNameProvider extends DeviceNameProvider {
  @override
  Future<String> readName(String platform) async => 'Test iPhone';
}

class _FakeShareReceiver extends ShareReceiver {
  @override
  Future<void> initialize() async {}
}
