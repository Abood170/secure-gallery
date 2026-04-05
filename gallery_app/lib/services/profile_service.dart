import '../config/api_config.dart';
import '../models/user_profile.dart';
import 'api_service.dart';

class ProfileService {
  /// Fetch the current user's full profile + stats.
  static Future<UserProfile> getProfile() async {
    final res = await ApiService.dio.get(ApiConfig.profile);
    return UserProfile.fromJson(res.data as Map<String, dynamic>);
  }

  /// Update email and/or password.
  /// [currentPassword] is always required to confirm the change.
  static Future<void> updateProfile({
    String? newEmail,
    String? newPassword,
    required String currentPassword,
  }) async {
    final body = <String, dynamic>{
      'current_password': currentPassword,
      if (newEmail    != null) 'new_email':    newEmail,
      if (newPassword != null) 'new_password': newPassword,
    };
    await ApiService.dio.patch(ApiConfig.profile, data: body);
  }

  /// Hard-delete the authenticated user's account.
  static Future<void> deleteAccount({required String password}) async {
    await ApiService.dio.delete(
      ApiConfig.profile,
      data: {'password': password},
    );
  }
}
