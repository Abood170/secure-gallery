// Mobile / desktop RSA implementation — uses the fast_rsa package which
// compiles Rust to a native shared library via FFI.
// This file is ONLY compiled on non-web targets (dart.library.io is true).

import 'package:fast_rsa/fast_rsa.dart' as rsa;

// ── Platform functions (must match the stub signature exactly) ────────────────

Future<Map<String, String>> platformRsaGenerateKeyPair() async {
  final pair = await rsa.RSA.generate(2048);
  // Convert to web-compatible formats so keys are interoperable with
  // SubtleCrypto (web):  public → SPKI  ("BEGIN PUBLIC KEY")
  //                      private → PKCS#8 ("BEGIN PRIVATE KEY")
  final spkiPublic   = await rsa.RSA.convertPublicKeyToPKIX(pair.publicKey);
  final pkcs8Private = await rsa.RSA.convertPrivateKeyToPKCS8(pair.privateKey);
  return {
    'privateKey': pkcs8Private,
    'publicKey':  spkiPublic,
  };
}

Future<String> platformRsaEncrypt(
    String publicKeyPem, String dataB64) async {
  // fast_rsa's encryptOAEP requires PKCS#1 format internally.
  // Recipient's key may be SPKI (web-registered user) so convert first —
  // convertPublicKeyToPKCS1 is idempotent if already PKCS#1.
  final pkcs1Key = await rsa.RSA.convertPublicKeyToPKCS1(publicKeyPem);
  return rsa.RSA.encryptOAEP(dataB64, '', rsa.Hash.SHA256, pkcs1Key);
}

Future<String> platformRsaDecrypt(
    String privateKeyPem, String encryptedB64) async {
  // fast_rsa's decryptOAEP requires PKCS#1 format internally.
  // Keys stored on device may be PKCS#8 (from web or the new mobile format),
  // so convert first — convertPrivateKeyToPKCS1 is idempotent if already PKCS#1.
  final pkcs1Key = await rsa.RSA.convertPrivateKeyToPKCS1(privateKeyPem);
  return rsa.RSA.decryptOAEP(encryptedB64, '', rsa.Hash.SHA256, pkcs1Key);
}
