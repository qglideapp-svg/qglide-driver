import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleSignInCredentials {
  const AppleSignInCredentials({
    required this.idToken,
    required this.rawNonce,
    this.givenName,
    this.familyName,
    this.email,
  });

  final String idToken;
  final String rawNonce;
  final String? givenName;
  final String? familyName;
  final String? email;
}

class AppleSignInService {
  AppleSignInService._();

  static Future<AppleSignInCredentials> getCredentials() async {
    final rawNonce = _randomNonce();
    final nonce = _sha256ofString(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Apple Sign In did not return an identity token.');
    }

    return AppleSignInCredentials(
      idToken: idToken,
      rawNonce: rawNonce,
      givenName: credential.givenName,
      familyName: credential.familyName,
      email: credential.email,
    );
  }

  static String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
