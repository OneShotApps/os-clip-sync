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
      deviceNameProvider: DeviceNameProvider(),
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

  testWidgets('selects and confirms deletion of multiple history items', (
    tester,
  ) async {
    final sessionStore = _FakeSessionStore();
    final apiClient = _FakeApiClient([
      _historyItem('E' * 32, 'first item'),
      _historyItem('F' * 32, 'second item'),
    ]);
    final controller = ClipSyncController(
      apiClient: apiClient,
      sessionStore: sessionStore,
      googleAuthService: GoogleAuthService(sessionStore: sessionStore),
      clipboard: ClipboardAdapter(),
      shareReceiver: _FakeShareReceiver(),
      deviceNameProvider: _FakeDeviceNameProvider(),
      platform: 'macos',
      isDesktop: false,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(ClipSyncApp(controller: controller));

    await tester.tap(find.byKey(ValueKey('select-item-${'E' * 32}')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('select-item-${'F' * 32}')));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete selected items'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 selected items?'), findsOneWidget);

    await tester.tap(find.text('Delete 2 items'));
    await tester.pumpAndSettle();

    expect(apiClient.deletedItemUids, ['E' * 32, 'F' * 32]);
    expect(controller.items, isEmpty);
  });
}

ClipItem _historyItem(String uid, String text) => ClipItem(
  uid: uid,
  kind: 'text',
  mimeType: 'text/plain',
  sizeBytes: text.length,
  sourcePlatform: 'ios',
  sourceDeviceName: 'Test iPhone',
  createdAt: DateTime.utc(2026, 8, 19),
  text: text,
);

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
  _FakeApiClient(this.historyItems) : super(baseUrl: 'http://example.test');

  final List<ClipItem> historyItems;
  final List<String> deletedItemUids = [];

  @override
  Future<SyncDevice> registerDevice({
    required AuthSession session,
    required String clientUid,
    required String platform,
    required String name,
  }) async => SyncDevice(uid: clientUid, name: name, platform: platform);

  @override
  Future<ClipItemPage> listHistory(
    AuthSession session, {
    required int page,
    int pageSize = 50,
  }) async => ClipItemPage(
    items: List<ClipItem>.from(historyItems),
    page: 1,
    totalPages: 1,
  );

  @override
  Future<void> deleteItem(AuthSession session, String itemUid) async {
    deletedItemUids.add(itemUid);
    historyItems.removeWhere((item) => item.uid == itemUid);
  }
}

class _FakeDeviceNameProvider extends DeviceNameProvider {
  @override
  Future<String> readName(String platform) async => 'Test Mac';
}

class _FakeShareReceiver extends ShareReceiver {
  @override
  Future<void> initialize() async {}
}
