import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

// Conditional import: the Dart compiler picks exactly ONE of these at build
// time.  No runtime switch, no dart:js_interop on native, no fast_rsa on web.
//
//   dart.library.js_interop → web / wasm  → crypto_rsa_web.dart
//   dart.library.io          → Android / iOS / desktop → crypto_rsa_mobile.dart
//   (fallback)               → crypto_rsa_stub.dart   (throws at runtime)
import 'crypto_rsa_stub.dart'
    if (dart.library.js_interop) 'crypto_rsa_web.dart'
    if (dart.library.io) 'crypto_rsa_mobile.dart';

/// Result returned by any symmetric encrypt call.
class EncryptResult {
  final Uint8List ciphertext; // cipherText bytes + 16-byte auth tag appended
  final String iv;            // Base64-encoded IV / nonce
  final String keyBase64;     // Base64-encoded symmetric key

  const EncryptResult({
    required this.ciphertext,
    required this.iv,
    required this.keyBase64,
  });
}

class CryptoService {
  // ── RSA Key Pair ─────────────────────────────────────────────────────────────

  /// Generates a 2048-bit RSA-OAEP key pair.
  /// Web: delegates to browser SubtleCrypto (fast, hardware-backed).
  /// Android/iOS: delegates to fast_rsa (Rust FFI, also hardware-backed).
  static Future<Map<String, String>> generateRsaKeyPair() =>
      platformRsaGenerateKeyPair();

  // ── RSA-OAEP Key Wrapping ────────────────────────────────────────────────────

  /// Wraps a Base64 symmetric key with the recipient's RSA public key (PEM).
  /// Returns Base64-encoded RSA ciphertext.
  static Future<String> rsaEncryptKey(
          String keyBase64, String publicKeyPem) =>
      platformRsaEncrypt(publicKeyPem, keyBase64);

  /// Unwraps a Base64 RSA ciphertext with the user's RSA private key (PEM).
  /// Returns the original Base64 symmetric key.
  static Future<String> rsaDecryptKey(
          String encryptedKeyBase64, String privateKeyPem) =>
      platformRsaDecrypt(privateKeyPem, encryptedKeyBase64);

  // ── AES-256-GCM ──────────────────────────────────────────────────────────────
  // Uses the `cryptography` pure-Dart package — identical on web and mobile.

  static Future<EncryptResult> encryptAesGcm(Uint8List plaintext) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = await algorithm.newSecretKey();
    final nonce     = algorithm.newNonce(); // 12 bytes

    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    final keyBytes = await secretKey.extractBytes();
    // Append 16-byte MAC to cipherText so a single blob is stored/transferred.
    final combined = Uint8List.fromList(
        secretBox.cipherText + secretBox.mac.bytes);

    return EncryptResult(
      ciphertext: combined,
      iv:         base64.encode(nonce),
      keyBase64:  base64.encode(keyBytes),
    );
  }

  static Future<Uint8List> decryptAesGcm({
    required Uint8List ciphertextWithMac,
    required String ivBase64,
    required String keyBase64,
  }) async {
    final algorithm = AesGcm.with256bits();
    final nonce     = base64.decode(ivBase64);
    final keyBytes  = base64.decode(keyBase64);

    // Last 16 bytes = MAC tag; the rest = cipher text.
    final mac        = Mac(ciphertextWithMac.sublist(ciphertextWithMac.length - 16));
    final cipherText = ciphertextWithMac.sublist(0, ciphertextWithMac.length - 16);

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
    final secretKey = SecretKey(keyBytes);
    final plaintext = await algorithm.decrypt(secretBox, secretKey: secretKey);
    return Uint8List.fromList(plaintext);
  }

  // ── ChaCha20-Poly1305 ─────────────────────────────────────────────────────────

  static Future<EncryptResult> encryptChaCha20(Uint8List plaintext) async {
    final algorithm = Chacha20.poly1305Aead();
    final secretKey = await algorithm.newSecretKey();
    final nonce     = algorithm.newNonce(); // 12 bytes

    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    final keyBytes = await secretKey.extractBytes();
    final combined = Uint8List.fromList(
        secretBox.cipherText + secretBox.mac.bytes);

    return EncryptResult(
      ciphertext: combined,
      iv:         base64.encode(nonce),
      keyBase64:  base64.encode(keyBytes),
    );
  }

  static Future<Uint8List> decryptChaCha20({
    required Uint8List ciphertextWithMac,
    required String ivBase64,
    required String keyBase64,
  }) async {
    final algorithm = Chacha20.poly1305Aead();
    final nonce     = base64.decode(ivBase64);
    final keyBytes  = base64.decode(keyBase64);

    final mac        = Mac(ciphertextWithMac.sublist(ciphertextWithMac.length - 16));
    final cipherText = ciphertextWithMac.sublist(0, ciphertextWithMac.length - 16);

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
    final secretKey = SecretKey(keyBytes);
    final plaintext = await algorithm.decrypt(secretBox, secretKey: secretKey);
    return Uint8List.fromList(plaintext);
  }

  // ── Dispatch helpers ──────────────────────────────────────────────────────────

  static Future<EncryptResult> encrypt(Uint8List plaintext, String algo) {
    switch (algo) {
      case 'AES-GCM':
        return encryptAesGcm(plaintext);
      case 'ChaCha20-Poly1305':
        return encryptChaCha20(plaintext);
      default:
        throw ArgumentError('Unsupported algorithm: $algo');
    }
  }

  static Future<Uint8List> decrypt({
    required Uint8List ciphertextWithMac,
    required String ivBase64,
    required String keyBase64,
    required String algo,
  }) {
    switch (algo) {
      case 'AES-GCM':
        return decryptAesGcm(
          ciphertextWithMac: ciphertextWithMac,
          ivBase64: ivBase64,
          keyBase64: keyBase64,
        );
      case 'ChaCha20-Poly1305':
        return decryptChaCha20(
          ciphertextWithMac: ciphertextWithMac,
          ivBase64: ivBase64,
          keyBase64: keyBase64,
        );
      default:
        throw ArgumentError('Unsupported algorithm: $algo');
    }
  }
}
