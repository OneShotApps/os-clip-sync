import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_handler/share_handler.dart';

/// Text or photo supplied by an operating-system share-to action.
class IncomingShare {
  const IncomingShare.text(this.text) : imageBytes = null, mimeType = null;

  const IncomingShare.image(this.imageBytes, this.mimeType) : text = null;

  final String? text;
  final Uint8List? imageBytes;
  final String? mimeType;
}

/// Receives Android/iOS share intents and Windows/macOS native share callbacks.
class ShareReceiver {
  static const _desktopChannel = MethodChannel('app.oneshot.clipsync/share');
  final _controller = StreamController<IncomingShare>.broadcast();
  StreamSubscription<SharedMedia>? _mobileSubscription;

  Stream<IncomingShare> get shares => _controller.stream;

  Future<void> initialize() async {
    _desktopChannel.setMethodCallHandler((call) async {
      if (call.method != 'received') return;
      final values = Map<String, dynamic>.from(call.arguments! as Map);
      final text = values['text'] as String?;
      if (text != null && text.isNotEmpty) {
        _controller.add(IncomingShare.text(text));
        return;
      }
      final bytes = values['imageBytes'];
      final mimeType = values['mimeType'] as String?;
      if (bytes is Uint8List && mimeType != null) {
        _controller.add(IncomingShare.image(bytes, mimeType));
      }
    });

    try {
      final pending = await _desktopChannel.invokeMapMethod<String, dynamic>(
        'takePending',
      );
      if (pending != null) {
        final text = pending['text'] as String?;
        final bytes = pending['imageBytes'];
        final mimeType = pending['mimeType'] as String?;
        if (text != null && text.isNotEmpty) {
          _controller.add(IncomingShare.text(text));
        } else if (bytes is Uint8List && mimeType != null) {
          _controller.add(IncomingShare.image(bytes, mimeType));
        }
      }
    } on MissingPluginException {
      // Android and iOS use share_handler instead of the desktop method channel.
    }

    if (!Platform.isAndroid && !Platform.isIOS) return;
    final handler = ShareHandlerPlatform.instance;
    final initial = await handler.getInitialSharedMedia();
    if (initial != null) await _emitMobile(initial);
    _mobileSubscription = handler.sharedMediaStream.listen(_emitMobile);
  }

  Future<void> _emitMobile(SharedMedia media) async {
    final text = media.content?.trim();
    if (text != null && text.isNotEmpty) {
      _controller.add(IncomingShare.text(text));
      return;
    }
    final attachments = media.attachments ?? const [];
    for (final attachment in attachments) {
      if (attachment == null || attachment.type != SharedAttachmentType.image) {
        continue;
      }
      final extension = attachment.path.split('.').last.toLowerCase();
      final mimeType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'png' => 'image/png',
        _ => null,
      };
      if (mimeType == null) continue;
      final bytes = await File(Uri.decodeFull(attachment.path)).readAsBytes();
      _controller.add(IncomingShare.image(bytes, mimeType));
      return;
    }
  }

  Future<void> dispose() async {
    await _mobileSubscription?.cancel();
    await _controller.close();
  }
}
