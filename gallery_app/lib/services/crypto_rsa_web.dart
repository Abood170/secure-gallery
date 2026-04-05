// Web RSA implementation — uses the browser's SubtleCrypto API via
// hand-written JS helpers defined in web/index.html.
// This file is ONLY compiled on web (dart.library.js_interop is true).

import 'dart:js_interop';

// ── JS bindings ───────────────────────────────────────────────────────────────

@JS('nativeGenerateRsaKeyPair')
external JSPromise _nativeGenerateRsaKeyPair();

@JS('nativeRsaEncrypt')
external JSPromise _nativeRsaEncrypt(String publicKeyPem, String dataB64);

@JS('nativeRsaDecrypt')
external JSPromise _nativeRsaDecrypt(String privateKeyPem, String dataB64);

extension type _RsaKeyPair(JSObject _) implements JSObject {
  external String get privateKey;
  external String get publicKey;
}

// ── Platform functions (must match the stub signature exactly) ────────────────

Future<Map<String, String>> platformRsaGenerateKeyPair() async {
  final result =
      (await _nativeGenerateRsaKeyPair().toDart) as _RsaKeyPair;
  return {
    'privateKey': result.privateKey,
    'publicKey':  result.publicKey,
  };
}

Future<String> platformRsaEncrypt(
    String publicKeyPem, String dataB64) async {
  final result =
      (await _nativeRsaEncrypt(publicKeyPem, dataB64).toDart) as JSString;
  return result.toDart;
}

Future<String> platformRsaDecrypt(
    String privateKeyPem, String encryptedB64) async {
  final result =
      (await _nativeRsaDecrypt(privateKeyPem, encryptedB64).toDart) as JSString;
  return result.toDart;
}
