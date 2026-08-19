import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// One persisted clipboard history item.
class ClipItem {
  const ClipItem({
    required this.uid,
    required this.kind,
    required this.mimeType,
    required this.sizeBytes,
    required this.sourcePlatform,
    required this.sourceDeviceName,
    required this.createdAt,
    this.text,
    this.imageBytes,
  });

  factory ClipItem.fromJson(Map<String, dynamic> json) => ClipItem(
    uid: json['uid']! as String,
    kind: json['kind']! as String,
    mimeType: json['mimeType']! as String,
    sizeBytes: json['sizeBytes']! as int,
    sourcePlatform: json['sourcePlatform']! as String,
    sourceDeviceName:
        json['sourceDeviceName'] as String? ??
        _platformDisplayName(json['sourcePlatform']! as String),
    createdAt: DateTime.parse(json['createdAt']! as String).toLocal(),
    text: json['text'] as String?,
    imageBytes: json['imageBase64'] == null
        ? null
        : base64Decode(json['imageBase64']! as String),
  );

  final String uid;
  final String kind;
  final String mimeType;
  final int sizeBytes;
  final String sourcePlatform;
  final String sourceDeviceName;
  final DateTime createdAt;
  final String? text;
  final Uint8List? imageBytes;

  bool get isText => kind == 'text';
  bool get isImage => kind == 'image';

  String get preview {
    if (isImage) return 'Photo (${(sizeBytes / 1024).ceil()} KB)';
    final value = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.length <= 100 ? value : '${value.substring(0, 100)}…';
  }

  String get contentDigest {
    final bytes = isText
        ? utf8.encode('text:${text ?? ''}')
        : imageBytes ?? <int>[];
    return sha256.convert(bytes).toString();
  }
}

String _platformDisplayName(String platform) => switch (platform) {
  'android' => 'Android',
  'ios' => 'iOS',
  'macos' => 'macOS',
  'windows' => 'Windows',
  _ => platform,
};

/// A page of history and its server-provided pagination state.
class ClipItemPage {
  const ClipItemPage({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  final List<ClipItem> items;
  final int page;
  final int totalPages;
}
