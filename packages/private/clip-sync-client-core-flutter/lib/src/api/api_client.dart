import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../models/auth_session.dart';
import '../models/clip_item.dart';
import '../models/sync_device.dart';
import 'api_exception.dart';

/// Connection wrapper that lets desktop synchronization close a WebSocket cleanly.
class RealtimeConnection {
  const RealtimeConnection({required this.items, required this.close});

  final Stream<ClipItem> items;
  final Future<void> Function() close;
}

/// Typed transport wrapper for all Clip Sync UX API calls.
class ClipSyncApiClient {
  ClipSyncApiClient({required String baseUrl, http.Client? client})
    : baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    AuthSession? session,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['content-type'] = 'application/json';
    if (session != null) {
      request.headers['authorization'] = 'Bearer ${session.accessToken}';
    }
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client.send(request);
    final responseBody = await streamed.stream.bytesToString();
    final decoded = responseBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(responseBody) as Map<String, dynamic>;
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ApiException(
        code: decoded['code'] as String? ?? 'CLIP_SYNC_TRANSPORT_ERROR',
        message:
            decoded['message'] as String? ??
            'The request could not be completed.',
        statusCode: streamed.statusCode,
      );
    }
    return decoded;
  }

  Future<Map<String, String>> requestEmailCode(String email) async {
    final response = await _request(
      'POST',
      '/ux/v1/auth/email/request',
      body: {'email': email},
    );
    return {
      'challengeUid': response['challengeUid']! as String,
      'expiresAt': response['expiresAt']! as String,
    };
  }

  Future<AuthSession> verifyEmailCode({
    required String challengeUid,
    required String code,
  }) async {
    final response = await _request(
      'POST',
      '/ux/v1/auth/email/verify',
      body: {'challengeUid': challengeUid, 'code': code},
    );
    return AuthSession.fromJson(response);
  }

  Future<AuthSession> signInWithGoogle(String idToken) async {
    final response = await _request(
      'POST',
      '/ux/v1/auth/google',
      body: {'idToken': idToken},
    );
    return AuthSession.fromJson(response);
  }

  Future<ClipItemPage> listHistory(
    AuthSession session, {
    required int page,
    int pageSize = 50,
  }) async {
    final response = await _request(
      'GET',
      '/ux/v1/history?page=$page&pageSize=$pageSize',
      session: session,
    );
    final pagination = response['pagination']! as Map<String, dynamic>;
    return ClipItemPage(
      items: (response['items']! as List<dynamic>)
          .map((item) => ClipItem.fromJson(item! as Map<String, dynamic>))
          .toList(),
      page: pagination['page']! as int,
      totalPages: pagination['totalPages']! as int,
    );
  }

  Future<SyncDevice> registerDevice({
    required AuthSession session,
    required String clientUid,
    required String platform,
    required String name,
  }) async {
    final response = await _request(
      'POST',
      '/ux/v1/devices/register',
      session: session,
      body: {'clientUid': clientUid, 'platform': platform, 'name': name},
    );
    return SyncDevice.fromJson(response['device']! as Map<String, dynamic>);
  }

  Future<List<SyncDevice>> listDevices(AuthSession session) async {
    final response = await _request('GET', '/ux/v1/devices', session: session);
    return (response['devices']! as List<dynamic>)
        .map((device) => SyncDevice.fromJson(device! as Map<String, dynamic>))
        .toList();
  }

  Future<SyncDevice> renameDevice({
    required AuthSession session,
    required String deviceUid,
    required String name,
  }) async {
    final response = await _request(
      'PATCH',
      '/ux/v1/devices/$deviceUid',
      session: session,
      body: {'name': name},
    );
    return SyncDevice.fromJson(response['device']! as Map<String, dynamic>);
  }

  Future<ClipItem> getItem(AuthSession session, String itemUid) async {
    final response = await _request(
      'GET',
      '/ux/v1/items/$itemUid',
      session: session,
    );
    return ClipItem.fromJson(response['item']! as Map<String, dynamic>);
  }

  Future<ClipItem> createTextItem({
    required AuthSession session,
    required String clientUid,
    required String platform,
    required String text,
  }) async {
    final response = await _request(
      'POST',
      '/ux/v1/items',
      session: session,
      body: {
        'clientUid': clientUid,
        'sourcePlatform': platform,
        'kind': 'text',
        'text': text,
      },
    );
    return ClipItem.fromJson(response['item']! as Map<String, dynamic>);
  }

  Future<ClipItem> createImageItem({
    required AuthSession session,
    required String clientUid,
    required String platform,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final response = await _request(
      'POST',
      '/ux/v1/items',
      session: session,
      body: {
        'clientUid': clientUid,
        'sourcePlatform': platform,
        'kind': 'image',
        'imageBase64': base64Encode(bytes),
        'mimeType': mimeType,
      },
    );
    return ClipItem.fromJson(response['item']! as Map<String, dynamic>);
  }

  Future<void> deleteItem(AuthSession session, String itemUid) async {
    await _request('DELETE', '/ux/v1/items/$itemUid', session: session);
  }

  RealtimeConnection connectRealtime({
    required AuthSession session,
    required String clientUid,
    required String platform,
  }) {
    final httpUri = Uri.parse(baseUrl);
    final uri = httpUri.replace(
      scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/ux/v1/realtime',
      queryParameters: {'clientUid': clientUid, 'platform': platform},
    );
    final channel = IOWebSocketChannel.connect(
      uri,
      headers: {'authorization': 'Bearer ${session.accessToken}'},
      pingInterval: const Duration(seconds: 20),
    );
    final items = channel.stream
        .map((message) => jsonDecode(message as String) as Map<String, dynamic>)
        .where((message) => message['type'] == 'clipboard-item')
        .map(
          (message) =>
              ClipItem.fromJson(message['item']! as Map<String, dynamic>),
        );
    return RealtimeConnection(
      items: items,
      close: () async => channel.sink.close(status.normalClosure),
    );
  }

  void close() => _client.close();
}
