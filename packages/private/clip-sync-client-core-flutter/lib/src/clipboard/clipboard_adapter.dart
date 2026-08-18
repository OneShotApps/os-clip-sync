import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../models/clip_item.dart';

/// Normalized content read from the operating-system clipboard.
class LocalClipboardContent {
  const LocalClipboardContent.text(this.text)
    : kind = 'text',
      bytes = null,
      mimeType = 'text/plain';

  const LocalClipboardContent.image(this.bytes)
    : kind = 'image',
      text = null,
      mimeType = 'image/png';

  final String kind;
  final String? text;
  final Uint8List? bytes;
  final String mimeType;

  String get digest {
    final data = kind == 'text'
        ? utf8.encode('text:${text ?? ''}')
        : bytes ?? <int>[];
    return sha256.convert(data).toString();
  }
}

/// Cross-platform clipboard access for text and photos.
class ClipboardAdapter {
  Future<Uint8List?> _readPng(ClipboardReader reader) async {
    final completer = Completer<Uint8List?>();
    final progress = reader.getFile(Formats.png, (file) async {
      try {
        completer.complete(await file.readAll());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }, onError: (error) => completer.completeError(error));
    if (progress == null) completer.complete(null);
    return completer.future;
  }

  Future<LocalClipboardContent?> readCurrent() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return null;
    final reader = await clipboard.read();
    if (reader.canProvide(Formats.png)) {
      final bytes = await _readPng(reader);
      if (bytes != null && bytes.isNotEmpty) {
        return LocalClipboardContent.image(bytes);
      }
    }
    if (reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);
      if (text != null && text.isNotEmpty) {
        return LocalClipboardContent.text(text);
      }
    }
    return null;
  }

  Future<void> writeItem(ClipItem item) async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      throw UnsupportedError('Clipboard access is unavailable.');
    }
    final writer = DataWriterItem();
    if (item.isText) {
      writer.add(Formats.plainText(item.text ?? ''));
    } else {
      final bytes = item.imageBytes;
      if (bytes == null) {
        throw StateError('Image content must be loaded before copying.');
      }
      if (item.mimeType == 'image/jpeg') {
        writer.add(Formats.jpeg(bytes));
      } else if (item.mimeType == 'image/webp') {
        writer.add(Formats.webp(bytes));
      } else {
        writer.add(Formats.png(bytes));
      }
    }
    await clipboard.write([writer]);
  }
}
