import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey     = 'jwt_token';
  static const _userIdKey    = 'user_id';
  static const _symKeyPrefix = 'sym_key_';
  static const _isAdminKey   = 'is_admin';

  // Per-user RSA key names
  static String _privateKeyKey(int userId) => 'rsa_private_key_$userId';
  static String _publicKeyKey(int userId)  => 'rsa_public_key_$userId';

  // ── JWT Token ────────────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  // ── Current User ID ──────────────────────────────────────────────────────────
  static Future<void> saveUserId(int userId) =>
      _storage.write(key: _userIdKey, value: userId.toString());

  static Future<int?> getUserId() async {
    final v = await _storage.read(key: _userIdKey);
    return v == null ? null : int.tryParse(v);
  }

  // ── RSA Key Pair (per user) ──────────────────────────────────────────────────
  static Future<void> saveKeyPair(int userId, String privateKey, String publicKey) async {
    await _storage.write(key: _privateKeyKey(userId), value: privateKey);
    await _storage.write(key: _publicKeyKey(userId),  value: publicKey);
  }

  static Future<String?> getPrivateKey() async {
    final uid = await getUserId();
    if (uid == null) return null;
    return _storage.read(key: _privateKeyKey(uid));
  }

  static Future<String?> getPublicKey() async {
    final uid = await getUserId();
    if (uid == null) return null;
    return _storage.read(key: _publicKeyKey(uid));
  }

  static Future<bool> hasKeyPair() async {
    final pk = await getPrivateKey();
    return pk != null;
  }

  // ── Symmetric Keys (owner's local key store, keyed by media_id) ──────────────
  static Future<void> saveSymmetricKey(int mediaId, String keyBase64) =>
      _storage.write(key: '$_symKeyPrefix$mediaId', value: keyBase64);

  static Future<String?> getSymmetricKey(int mediaId) =>
      _storage.read(key: '$_symKeyPrefix$mediaId');

  static Future<void> deleteSymmetricKey(int mediaId) =>
      _storage.delete(key: '$_symKeyPrefix$mediaId');

  // ── Admin flag ────────────────────────────────────────────────────────────────
  static Future<void> saveIsAdmin(bool value) =>
      _storage.write(key: _isAdminKey, value: value.toString());

  static Future<bool> getIsAdmin() async {
    final v = await _storage.read(key: _isAdminKey);
    return v == 'true';
  }

  // ── Legacy key migration (pre-userId storage) ────────────────────────────────
  static Future<Map<String, String>?> getLegacyKeyPair() async {
    final priv = await _storage.read(key: 'rsa_private_key');
    final pub  = await _storage.read(key: 'rsa_public_key');
    if (priv != null && pub != null) return {'privateKey': priv, 'publicKey': pub};
    return null;
  }

  static Future<void> clearLegacyKeyPair() async {
    await _storage.delete(key: 'rsa_private_key');
    await _storage.delete(key: 'rsa_public_key');
  }

  // ── Session data only (JWT + admin flag + userId) ────────────────────────────
  // RSA key pairs are intentionally kept so existing shares stay decryptable.
  static Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _isAdminKey);
  }

  // ── Wipe everything (hard reset / account deletion) ───────────────────────────
  static Future<void> clearAll() => _storage.deleteAll();
}
