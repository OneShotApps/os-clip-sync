/// Authenticated account context returned by the Clip Sync API.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    required this.accountUid,
    required this.email,
    required this.clipboardUid,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final account = json['account']! as Map<String, dynamic>;
    return AuthSession(
      accessToken: json['accessToken']! as String,
      expiresAt: DateTime.parse(json['expiresAt']! as String),
      accountUid: account['uid']! as String,
      email: account['email']! as String,
      clipboardUid: account['clipboardUid']! as String,
    );
  }

  factory AuthSession.fromStorage(Map<String, String> values) => AuthSession(
    accessToken: values['accessToken']!,
    expiresAt: DateTime.parse(values['expiresAt']!),
    accountUid: values['accountUid']!,
    email: values['email']!,
    clipboardUid: values['clipboardUid']!,
  );

  final String accessToken;
  final DateTime expiresAt;
  final String accountUid;
  final String email;
  final String clipboardUid;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  Map<String, String> toStorage() => {
    'accessToken': accessToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'accountUid': accountUid,
    'email': email,
    'clipboardUid': clipboardUid,
  };
}
