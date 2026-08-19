import 'dart:async';
import 'dart:convert';

import 'package:clip_sync_client_core/clip_sync_client_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('auth session round-trips through secure-storage values', () {
    final session = AuthSession(
      accessToken: 'token',
      expiresAt: DateTime.utc(2099),
      accountUid: 'A' * 32,
      email: 'person@example.com',
      clipboardUid: 'B' * 32,
    );

    final restored = AuthSession.fromStorage(session.toStorage());

    expect(restored.accessToken, 'token');
    expect(restored.accountUid, 'A' * 32);
    expect(restored.clipboardUid, 'B' * 32);
    expect(restored.isExpired, isFalse);
  });

  test('text item produces a stable preview and digest', () {
    final item = ClipItem(
      uid: 'C' * 32,
      kind: 'text',
      mimeType: 'text/plain',
      sizeBytes: utf8.encode('hello world').length,
      sourcePlatform: 'windows',
      sourceDeviceName: 'Office PC',
      createdAt: DateTime.utc(2026, 8, 18),
      text: 'hello   world',
    );

    expect(item.preview, 'hello world');
    expect(item.contentDigest, hasLength(64));
    expect(item.contentDigest, item.contentDigest);
  });

  test(
    'keeps a session in memory when secure storage is unavailable',
    () async {
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'missing-entitlement');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final store = SessionStore(allowVolatileFallback: true);
      final session = _session();

      final firstClientUid = await store.readOrCreateClientUid();
      await store.writeSession(session);

      expect(await store.readOrCreateClientUid(), firstClientUid);
      final restored = await store.readSession();
      expect(restored?.accessToken, session.accessToken);
      expect(restored?.accountUid, session.accountUid);
    },
  );

  test(
    'captures an operating-system share emitted during initialization',
    () async {
      final session = _session();
      final store = _FakeSessionStore(session);
      final api = _FakeApiClient();
      final shares = _FakeShareReceiver(initialText: 'shared before startup');
      final controller = ClipSyncController(
        apiClient: api,
        sessionStore: store,
        googleAuthService: GoogleAuthService(sessionStore: store),
        clipboard: ClipboardAdapter(),
        shareReceiver: shares,
        deviceNameProvider: _FakeDeviceNameProvider(),
        platform: 'android',
        isDesktop: false,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(api.createdTexts, ['shared before startup']);
      expect(controller.items.single.text, 'shared before startup');
    },
  );

  test('refresh replaces stale mobile history with the newest page', () async {
    final session = _session();
    final store = _FakeSessionStore(session);
    final api = _FakeApiClient()..historyText = 'old item';
    final controller = ClipSyncController(
      apiClient: api,
      sessionStore: store,
      googleAuthService: GoogleAuthService(sessionStore: store),
      clipboard: ClipboardAdapter(),
      shareReceiver: _FakeShareReceiver(),
      deviceNameProvider: _FakeDeviceNameProvider(),
      platform: 'ios',
      isDesktop: false,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.items.single.text, 'old item');

    api.historyText = 'new item';
    await controller.refreshHistory();

    expect(controller.items, hasLength(1));
    expect(controller.items.single.text, 'new item');
  });

  test('deletes multiple selected history items', () async {
    final session = _session();
    final store = _FakeSessionStore(session);
    final api = _FakeApiClient()
      ..historyTexts.addAll(['first item', 'second item']);
    final controller = ClipSyncController(
      apiClient: api,
      sessionStore: store,
      googleAuthService: GoogleAuthService(sessionStore: store),
      clipboard: ClipboardAdapter(),
      shareReceiver: _FakeShareReceiver(),
      deviceNameProvider: _FakeDeviceNameProvider(),
      platform: 'ios',
      isDesktop: false,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final selectedItems = controller.items;

    await controller.deleteItems(selectedItems);

    expect(api.deletedItemUids, selectedItems.map((item) => item.uid));
    expect(controller.items, isEmpty);
  });

  test(
    'registers the OS name and refreshes history after renaming a device',
    () async {
      final session = _session();
      final store = _FakeSessionStore(session);
      final api = _FakeApiClient()..historyText = 'named item';
      final controller = ClipSyncController(
        apiClient: api,
        sessionStore: store,
        googleAuthService: GoogleAuthService(sessionStore: store),
        clipboard: ClipboardAdapter(),
        shareReceiver: _FakeShareReceiver(),
        deviceNameProvider: _FakeDeviceNameProvider(),
        platform: 'ios',
        isDesktop: false,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(api.registeredName, 'Test device');
      await controller.refreshDevices();
      final otherDevice = controller.devices.firstWhere(
        (device) => device.uid == 'E' * 32,
      );
      final historyRequestsBeforeRename = api.historyRequestCount;

      await controller.renameDevice(otherDevice, 'Travel phone');

      expect(
        controller.devices.firstWhere((device) => device.uid == 'E' * 32).name,
        'Travel phone',
      );
      expect(api.historyRequestCount, historyRequestsBeforeRename + 1);
    },
  );

  testWidgets(
    'history refresh slows down, pauses, and resumes after manual refresh',
    (tester) async {
      var now = DateTime.utc(2026, 8, 19);
      var refreshCount = 0;
      final scheduler = HistoryRefreshScheduler(
        onRefresh: () async {
          refreshCount += 1;
        },
        fastInterval: const Duration(seconds: 1),
        fastPhaseDuration: const Duration(seconds: 2),
        slowInterval: const Duration(seconds: 3),
        pauseAfter: const Duration(seconds: 8),
        now: () => now,
      );
      addTearDown(scheduler.dispose);

      Future<void> advance(Duration duration) async {
        now = now.add(duration);
        await tester.pump(duration);
        await tester.pump();
      }

      scheduler.start();
      await advance(const Duration(seconds: 1));
      expect(refreshCount, 1);
      await advance(const Duration(seconds: 1));
      expect(refreshCount, 2);
      await advance(const Duration(seconds: 3));
      expect(refreshCount, 3);

      await advance(const Duration(seconds: 3));
      expect(scheduler.isPaused, isTrue);
      expect(refreshCount, 3);

      await scheduler.refreshNow();
      expect(scheduler.isPaused, isFalse);
      expect(refreshCount, 4);

      scheduler.stop();
      await advance(const Duration(seconds: 10));
      expect(refreshCount, 4);
    },
  );
}

AuthSession _session() => AuthSession(
  accessToken: 'token',
  expiresAt: DateTime.utc(2099),
  accountUid: 'A' * 32,
  email: 'person@example.com',
  clipboardUid: 'B' * 32,
);

ClipItem _textItem(String text, int sequence) => ClipItem(
  uid: sequence.toString().padLeft(32, 'C'),
  kind: 'text',
  mimeType: 'text/plain',
  sizeBytes: utf8.encode(text).length,
  sourcePlatform: 'android',
  sourceDeviceName: 'Pixel',
  createdAt: DateTime.utc(2026, 8, 18),
  text: text,
);

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore(this.savedSession);

  AuthSession? savedSession;

  @override
  Future<String> readOrCreateClientUid() async => 'D' * 32;

  @override
  Future<AuthSession?> readSession() async => savedSession;

  @override
  Future<void> writeSession(AuthSession session) async {
    savedSession = session;
  }
}

class _FakeApiClient extends ClipSyncApiClient {
  _FakeApiClient() : super(baseUrl: 'http://example.test');

  final List<String> createdTexts = [];
  final List<String> deletedItemUids = [];
  final List<String> historyTexts = [];
  final List<SyncDevice> accountDevices = [
    SyncDevice(uid: 'E' * 32, name: 'Other phone', platform: 'android'),
  ];
  String? historyText;
  String? registeredName;
  int historyRequestCount = 0;
  int _sequence = 1;

  @override
  Future<SyncDevice> registerDevice({
    required AuthSession session,
    required String clientUid,
    required String platform,
    required String name,
  }) async {
    registeredName = name;
    final device = SyncDevice(uid: clientUid, name: name, platform: platform);
    accountDevices.add(device);
    return device;
  }

  @override
  Future<List<SyncDevice>> listDevices(AuthSession session) async =>
      List<SyncDevice>.from(accountDevices);

  @override
  Future<SyncDevice> renameDevice({
    required AuthSession session,
    required String deviceUid,
    required String name,
  }) async {
    final index = accountDevices.indexWhere(
      (device) => device.uid == deviceUid,
    );
    final renamed = SyncDevice(
      uid: deviceUid,
      name: name,
      platform: accountDevices[index].platform,
    );
    accountDevices[index] = renamed;
    return renamed;
  }

  @override
  Future<ClipItemPage> listHistory(
    AuthSession session, {
    required int page,
    int pageSize = 50,
  }) async {
    historyRequestCount += 1;
    return ClipItemPage(
      items: historyTexts.isNotEmpty
          ? historyTexts.map((text) => _textItem(text, _sequence++)).toList()
          : historyText == null
          ? []
          : [_textItem(historyText!, _sequence++)],
      page: 1,
      totalPages: 1,
    );
  }

  @override
  Future<void> deleteItem(AuthSession session, String itemUid) async {
    deletedItemUids.add(itemUid);
  }

  @override
  Future<ClipItem> createTextItem({
    required AuthSession session,
    required String clientUid,
    required String platform,
    required String text,
  }) async {
    createdTexts.add(text);
    return _textItem(text, _sequence++);
  }
}

class _FakeDeviceNameProvider extends DeviceNameProvider {
  @override
  Future<String> readName(String platform) async => 'Test device';
}

class _FakeShareReceiver extends ShareReceiver {
  _FakeShareReceiver({this.initialText});

  final String? initialText;
  final StreamController<IncomingShare> _shares = StreamController.broadcast();

  @override
  Stream<IncomingShare> get shares => _shares.stream;

  @override
  Future<void> initialize() async {
    if (initialText != null) _shares.add(IncomingShare.text(initialText));
  }

  @override
  Future<void> dispose() => _shares.close();
}
