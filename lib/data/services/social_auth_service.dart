import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../config/env.dart';

/// Obtiene credenciales de proveedores sociales. La app nunca confía en el
/// token social: lo envía al backend para verificación server-side (ADR-007).
class SocialAuthService {
  bool _googleInicializado = false;

  Future<void> _initGoogle() async {
    if (_googleInicializado) return;
    await GoogleSignIn.instance.initialize(
      serverClientId:
          Env.googleServerClientId.isEmpty ? null : Env.googleServerClientId,
    );
    _googleInicializado = true;
  }

  /// Devuelve el `idToken` de Google, o `null` si el usuario cancela.
  /// Lanza si el flujo nativo falla.
  Future<String?> googleIdToken() async {
    await _initGoogle();
    final cuenta = await GoogleSignIn.instance.authenticate();
    return cuenta.authentication.idToken;
  }

  /// Devuelve el `identityToken` de Apple (uso futuro — design Q1).
  Future<String?> appleIdentityToken() async {
    final cred = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    return cred.identityToken;
  }
}
