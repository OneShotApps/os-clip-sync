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
  String? historyText;
  int _sequence = 1;

  @override
  Future<ClipItemPage> listHistory(
    AuthSession session, {
    required int page,
    int pageSize = 50,
  }) async => ClipItemPage(
    items: historyText == null ? [] : [_textItem(historyText!, _sequence++)],
    page: 1,
    totalPages: 1,
  );

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
