import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:cryptography/cryptography.dart';
import 'package:fast_rsa/fast_rsa.dart' as rsa;
import 'package:flutter/foundation.dart' show kIsWeb;

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

  static Future<Map<String, String>> generateRsaKeyPair() async {
    if (kIsWeb) {
      // Use browser's native SubtleCrypto — generates RSA-2048 in milliseconds.
      final result = (await _nativeGenerateRsaKeyPair().toDart) as _RsaKeyPair;
      return {
        'privateKey': result.privateKey,
        'publicKey':  result.publicKey,
      };
    }
    // Native (Android/iOS): fast_rsa uses hardware-accelerated RSA.
    final pair = await rsa.RSA.generate(2048);
    return {'privateKey': pair.privateKey, 'publicKey': pair.publicKey};
  }

  // ── RSA-OAEP Key Wrapping ────────────────────────────────────────────────────

  /// Encrypt a Base64 symmetric key with recipient's RSA public key (PEM).
  /// Returns Base64-encoded RSA ciphertext.
  static Future<String> rsaEncryptKey(
      String keyBase64, String publicKeyPem) async {
    if (kIsWeb) {
      final result = (await _nativeRsaEncrypt(publicKeyPem, keyBase64).toDart) as JSString;
      return result.toDart;
    }
    return rsa.RSA.encryptOAEP(keyBase64, '', rsa.Hash.SHA256, publicKeyPem);
  }

  static Future<String> rsaDecryptKey(
      String encryptedKeyBase64, String privateKeyPem) async {
    if (kIsWeb) {
      final result = (await _nativeRsaDecrypt(privateKeyPem, encryptedKeyBase64).toDart) as JSString;
      return result.toDart;
    }
    return rsa.RSA.decryptOAEP(encryptedKeyBase64, '', rsa.Hash.SHA256, privateKeyPem);
  }

  // ── AES-256-GCM ──────────────────────────────────────────────────────────────

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
    // Store cipherText + 16-byte MAC together in the uploaded file
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
    final nonce    = base64.decode(ivBase64);
    final keyBytes = base64.decode(keyBase64);

    // Last 16 bytes = MAC tag; the rest = cipher text
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
    final nonce    = base64.decode(ivBase64);
    final keyBytes = base64.decode(keyBase64);

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
