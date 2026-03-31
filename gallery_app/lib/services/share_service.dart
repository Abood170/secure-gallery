import '../config/api_config.dart';
import '../models/share_item.dart';
import 'api_service.dart';

class ShareService {
  static Future<Map<String, dynamic>> getUserByEmail(String email) async {
    final res = await ApiService.dio.get(
      ApiConfig.userByEmail,
      queryParameters: {'email': email},
    );
    return res.data as Map<String, dynamic>;
  }

  static Future<int> createShare({
    required int mediaId,
    required int receiverId,
    required String encryptedKey,
    String? expiresAt,
  }) async {
    final body = <String, dynamic>{
      'media_id':      mediaId,
      'receiver_id':   receiverId,
      'encrypted_key': encryptedKey,
      if (expiresAt != null) 'expires_at': expiresAt,
    };
    final res = await ApiService.dio.post(ApiConfig.createShare, data: body);
    return res.data['share_id'] as int;
  }

  static Future<List<ShareItem>> getInbox() async {
    final res  = await ApiService.dio.get(ApiConfig.inbox);
    final list = res.data['shares'] as List;
    return list
        .map((e) => ShareItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<String> getEncryptedKey(int shareId) async {
    final res = await ApiService.dio.get(ApiConfig.shareKey(shareId));
    return res.data['encrypted_key'] as String;
  }

  static Future<void> deleteShare(int shareId) async {
    await ApiService.dio.delete(ApiConfig.deleteShare(shareId));
  }
}
