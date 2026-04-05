// Fallback stub — never reached in practice because every Flutter target
// satisfies either dart.library.js_interop (web/wasm) or dart.library.io
// (Android, iOS, desktop).  Throws clearly if something unexpected happens.

Future<Map<String, String>> platformRsaGenerateKeyPair() =>
    throw UnsupportedError('RSA is not available on this platform');

Future<String> platformRsaEncrypt(String publicKeyPem, String dataB64) =>
    throw UnsupportedError('RSA is not available on this platform');

Future<String> platformRsaDecrypt(String privateKeyPem, String encryptedB64) =>
    throw UnsupportedError('RSA is not available on this platform');
