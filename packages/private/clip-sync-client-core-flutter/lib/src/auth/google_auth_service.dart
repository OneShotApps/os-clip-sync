import 'dart:io';

import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';

import 'session_store.dart';

/// Obtains a Google OpenID Connect ID token on every supported native platform.
class GoogleAuthService {
  GoogleAuthService({
    required SessionStore sessionStore,
    String clientId = const String.fromEnvironment(
      'CLIP_SYNC_GOOGLE_CLIENT_ID',
    ),
    String clientSecret = const String.fromEnvironment(
      'CLIP_SYNC_GOOGLE_CLIENT_SECRET',
    ),
    int redirectPort = const int.fromEnvironment(
      'CLIP_SYNC_GOOGLE_REDIRECT_PORT',
      defaultValue: 8000,
    ),
  }) : _googleSignIn = _canInitialize(clientId, clientSecret)
           ? GoogleSignIn(
               params: GoogleSignInParams(
                 clientId: clientId.isEmpty ? null : clientId,
                 clientSecret: clientSecret.isEmpty ? null : clientSecret,
                 redirectPort: redirectPort,
                 scopes: const ['openid', 'profile', 'email'],
                 saveAccessToken: sessionStore.writeGoogleAccessToken,
                 retrieveAccessToken: sessionStore.readGoogleAccessToken,
                 deleteAccessToken: sessionStore.clearGoogleAccessToken,
               ),
             )
           : null;

  final GoogleSignIn? _googleSignIn;

  static bool _canInitialize(String clientId, String clientSecret) {
    final desktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    return clientId.isNotEmpty && (!desktop || clientSecret.isNotEmpty);
  }

  Future<String> signInForIdToken() async {
    final googleSignIn = _googleSignIn;
    if (googleSignIn == null) {
      throw StateError(
        'Google sign-in is not configured. Provide CLIP_SYNC_GOOGLE_CLIENT_ID and, '
        'for desktop, CLIP_SYNC_GOOGLE_CLIENT_SECRET as Dart defines.',
      );
    }
    final credentials = await googleSignIn.signIn();
    final idToken = credentials?.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google sign-in did not return an OpenID Connect ID token.',
      );
    }
    return idToken;
  }

  Future<void> signOut() async => _googleSignIn?.signOut();
}
