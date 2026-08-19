/// One installed Clip Sync client owned by the authenticated account.
class SyncDevice {
  const SyncDevice({
    required this.uid,
    required this.name,
    required this.platform,
  });

  factory SyncDevice.fromJson(Map<String, dynamic> json) => SyncDevice(
    uid: json['uid']! as String,
    name: json['name']! as String,
    platform: json['platform']! as String,
  );

  final String uid;
  final String name;
  final String platform;

  String get platformName => platformDisplayName(platform);

  /// Converts API platform codes to labels intended for people.
  static String platformDisplayName(String platform) => switch (platform) {
    'android' => 'Android',
    'ios' => 'iOS',
    'macos' => 'macOS',
    'windows' => 'Windows',
    _ => platform,
  };
}
