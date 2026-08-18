import 'dart:async';

import '../api/api_client.dart';
import '../clipboard/clipboard_adapter.dart';
import '../models/auth_session.dart';
import '../models/clip_item.dart';

/// Monitors one desktop clipboard and receives online-only real-time delivery.
class DesktopSyncController {
  DesktopSyncController({
    required this.apiClient,
    required this.clipboard,
    required this.clientUid,
    required this.platform,
    required this.onItemUploaded,
    required this.onItemReceived,
    required this.onError,
  });

  final ClipSyncApiClient apiClient;
  final ClipboardAdapter clipboard;
  final String clientUid;
  final String platform;
  final void Function(ClipItem item) onItemUploaded;
  final void Function(ClipItem item) onItemReceived;
  final void Function(Object error) onError;

  AuthSession? _session;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  StreamSubscription<ClipItem>? _realtimeSubscription;
  RealtimeConnection? _connection;
  bool _capturing = false;
  bool _running = false;
  bool _paused = false;
  String? _lastDigest;
  DateTime _nextUploadAttempt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isPaused => _paused;

  Future<void> start(AuthSession session) async {
    await stop();
    _session = session;
    _running = true;
    _lastDigest = (await clipboard.readCurrent())?.digest;
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _captureClipboard(),
    );
    _connectRealtime();
  }

  Future<void> setPaused(bool paused) async {
    if (_paused == paused) return;
    if (!paused) {
      _lastDigest = (await clipboard.readCurrent())?.digest;
    }
    _paused = paused;
  }

  Future<void> _captureClipboard() async {
    final session = _session;
    if (!_running || _paused || _capturing || session == null) return;
    if (DateTime.now().isBefore(_nextUploadAttempt)) return;
    _capturing = true;
    try {
      final content = await clipboard.readCurrent();
      if (content == null || content.digest == _lastDigest) return;
      final item = content.kind == 'text'
          ? await apiClient.createTextItem(
              session: session,
              clientUid: clientUid,
              platform: platform,
              text: content.text!,
            )
          : await apiClient.createImageItem(
              session: session,
              clientUid: clientUid,
              platform: platform,
              bytes: content.bytes!,
              mimeType: content.mimeType,
            );
      _lastDigest = content.digest;
      _nextUploadAttempt = DateTime.fromMillisecondsSinceEpoch(0);
      onItemUploaded(item);
    } catch (error) {
      _nextUploadAttempt = DateTime.now().add(const Duration(seconds: 5));
      onError(error);
    } finally {
      _capturing = false;
    }
  }

  void _connectRealtime() {
    final session = _session;
    if (!_running || session == null) return;
    try {
      final connection = apiClient.connectRealtime(
        session: session,
        clientUid: clientUid,
        platform: platform,
      );
      _connection = connection;
      _realtimeSubscription = connection.items.listen(
        (item) async {
          try {
            await applyWithoutUpload(item);
            onItemReceived(item);
          } catch (error) {
            onError(error);
          }
        },
        onError: (Object error) {
          onError(error);
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
      );
    } catch (error) {
      onError(error);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_running || _reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      _reconnectTimer = null;
      await _realtimeSubscription?.cancel();
      await _connection?.close();
      _connectRealtime();
    });
  }

  /// Writes a remote or history item and immediately baselines the normalized clipboard.
  Future<void> applyWithoutUpload(ClipItem item) async {
    await clipboard.writeItem(item);
    _lastDigest = (await clipboard.readCurrent())?.digest;
  }

  Future<void> stop() async {
    _running = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    await _connection?.close();
    _connection = null;
    _session = null;
  }
}
