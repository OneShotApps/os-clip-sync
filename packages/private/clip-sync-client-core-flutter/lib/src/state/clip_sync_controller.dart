import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../auth/google_auth_service.dart';
import '../auth/session_store.dart';
import '../clipboard/clipboard_adapter.dart';
import '../models/auth_session.dart';
import '../models/clip_item.dart';
import '../sharing/share_receiver.dart';
import '../sync/desktop_sync_controller.dart';

/// Presentation-facing state for authentication, history, copy, delete, and share flows.
class ClipSyncController extends ChangeNotifier {
  ClipSyncController({
    required this.apiClient,
    required this.sessionStore,
    required this.googleAuthService,
    required this.clipboard,
    required this.shareReceiver,
    required this.platform,
    required this.isDesktop,
  });

  final ClipSyncApiClient apiClient;
  final SessionStore sessionStore;
  final GoogleAuthService googleAuthService;
  final ClipboardAdapter clipboard;
  final ShareReceiver shareReceiver;
  final String platform;
  final bool isDesktop;

  final List<ClipItem> _items = [];
  final List<IncomingShare> _pendingShares = [];
  StreamSubscription<IncomingShare>? _shareSubscription;
  DesktopSyncController? _desktopSync;
  AuthSession? _session;
  String? _clientUid;
  String? _emailChallengeUid;
  int _loadedPage = 0;
  int _totalPages = 0;
  bool _busy = true;
  String? _errorMessage;

  List<ClipItem> get items => List.unmodifiable(_items);
  AuthSession? get session => _session;
  bool get isAuthenticated => _session != null;
  bool get isBusy => _busy;
  bool get hasMoreHistory => _loadedPage < _totalPages;
  bool get isPaused => _desktopSync?.isPaused ?? false;
  String? get errorMessage => _errorMessage;
  String? get emailChallengeUid => _emailChallengeUid;

  Future<void> initialize() async {
    _busy = true;
    notifyListeners();
    try {
      _clientUid = await sessionStore.readOrCreateClientUid();
      _shareSubscription = shareReceiver.shares.listen(_receiveShare);
      await shareReceiver.initialize();
      _session = await sessionStore.readSession();
      if (_session != null) await _startAuthenticatedState();
    } catch (error) {
      _setError(error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> requestEmailCode(String email) async {
    await _runBusy(() async {
      final challenge = await apiClient.requestEmailCode(email);
      _emailChallengeUid = challenge['challengeUid'];
    });
  }

  Future<void> verifyEmailCode(String code) async {
    final challengeUid = _emailChallengeUid;
    if (challengeUid == null) throw StateError('Request an email code first.');
    await _runBusy(() async {
      final session = await apiClient.verifyEmailCode(
        challengeUid: challengeUid,
        code: code,
      );
      await _completeSignIn(session);
    });
  }

  Future<void> signInWithGoogle() async {
    await _runBusy(() async {
      final idToken = await googleAuthService.signInForIdToken();
      await _completeSignIn(await apiClient.signInWithGoogle(idToken));
    });
  }

  Future<void> _completeSignIn(AuthSession session) async {
    _session = session;
    _emailChallengeUid = null;
    await sessionStore.writeSession(session);
    await _startAuthenticatedState();
  }

  Future<void> _startAuthenticatedState() async {
    _items.clear();
    _loadedPage = 0;
    _totalPages = 0;
    await _loadMoreHistory();
    if (isDesktop) {
      _desktopSync = DesktopSyncController(
        apiClient: apiClient,
        clipboard: clipboard,
        clientUid: _clientUid!,
        platform: platform,
        onItemUploaded: _prependItem,
        onItemReceived: _prependItem,
        onError: _setError,
      );
      await _desktopSync!.start(_session!);
    }
    final shares = List<IncomingShare>.from(_pendingShares);
    _pendingShares.clear();
    for (final share in shares) {
      await _submitShare(share);
    }
  }

  Future<void> _loadMoreHistory() async {
    final session = _session;
    if (session == null || (_totalPages > 0 && _loadedPage >= _totalPages)) {
      return;
    }
    final page = await apiClient.listHistory(session, page: _loadedPage + 1);
    final existingUids = _items.map((item) => item.uid).toSet();
    _items.addAll(page.items.where((item) => !existingUids.contains(item.uid)));
    _loadedPage = page.page;
    _totalPages = page.totalPages;
    notifyListeners();
  }

  Future<void> loadMoreHistory() => _runBusy(_loadMoreHistory);

  /// Reloads the newest history page after a client has been idle.
  Future<void> refreshHistory() => _runBusy(() async {
    if (_session == null) return;
    _items.clear();
    _loadedPage = 0;
    _totalPages = 0;
    await _loadMoreHistory();
  });

  Future<void> copyItem(ClipItem item) async {
    final session = _session;
    if (session == null) return;
    await _runBusy(() async {
      final completeItem = item.isImage && item.imageBytes == null
          ? await apiClient.getItem(session, item.uid)
          : item;
      if (_desktopSync != null) {
        await _desktopSync!.applyWithoutUpload(completeItem);
      } else {
        await clipboard.writeItem(completeItem);
      }
    });
  }

  Future<void> deleteItem(ClipItem item) async {
    final session = _session;
    if (session == null) return;
    await _runBusy(() async {
      await apiClient.deleteItem(session, item.uid);
      _items.removeWhere((candidate) => candidate.uid == item.uid);
    });
  }

  Future<void> setPaused(bool paused) async {
    try {
      await _desktopSync?.setPaused(paused);
      notifyListeners();
    } catch (error) {
      _setError(error);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _runBusy(() async {
      await _desktopSync?.stop();
      _desktopSync = null;
      await googleAuthService.signOut();
      await sessionStore.clearSession();
      _session = null;
      _items.clear();
      _loadedPage = 0;
      _totalPages = 0;
    });
  }

  void _receiveShare(IncomingShare share) {
    if (_session == null) {
      _pendingShares.add(share);
      notifyListeners();
      return;
    }
    unawaited(_submitShare(share));
  }

  Future<void> _submitShare(IncomingShare share) async {
    final session = _session;
    if (session == null) return;
    try {
      final item = share.text != null
          ? await apiClient.createTextItem(
              session: session,
              clientUid: _clientUid!,
              platform: platform,
              text: share.text!,
            )
          : await apiClient.createImageItem(
              session: session,
              clientUid: _clientUid!,
              platform: platform,
              bytes: share.imageBytes!,
              mimeType: share.mimeType!,
            );
      _prependItem(item);
    } catch (error) {
      _setError(error);
    }
  }

  void _prependItem(ClipItem item) {
    _items.removeWhere((candidate) => candidate.uid == item.uid);
    _items.insert(0, item);
    notifyListeners();
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _setError(error);
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _setError(Object error) {
    _errorMessage = error.toString().replaceFirst('Exception: ', '');
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_desktopSync?.stop());
    unawaited(_shareSubscription?.cancel());
    unawaited(shareReceiver.dispose());
    apiClient.close();
    super.dispose();
  }
}
