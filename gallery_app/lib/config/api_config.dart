import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Web → localhost, Android emulator → 10.0.2.2, physical device → your PC's LAN IP
  static String get baseUrl =>
      kIsWeb ? 'http://192.168.100.5:4000' : 'http://192.168.100.5:4000';

  static const String register        = '/api/auth/register';
  static const String login           = '/api/auth/login';
  static const String updatePublicKey = '/api/auth/public-key';
  static const String listMedia   = '/api/media';
  static const String uploadMedia = '/api/media/upload';
  static const String createShare = '/api/share';
  static const String inbox       = '/api/share/inbox';
  static const String userByEmail = '/api/users/by-email';

  static String downloadMedia(int id)  => '/api/media/$id';
  static String deleteMedia(int id)    => '/api/media/$id';
  static String shareKey(int id)       => '/api/share/$id/key';
  static String downloadShared(int id) => '/api/share/$id/download';
  static String deleteShare(int id)    => '/api/share/$id';

  static const String adminStats     = '/api/admin/stats';
  static const String adminUsers     = '/api/admin/users';
  static const String adminMedia     = '/api/admin/media';
  static const String adminAuditLogs = '/api/admin/audit-logs';

  static String adminDeleteUser(int id)  => '/api/admin/users/$id';
  static String adminUpdateRole(int id)  => '/api/admin/users/$id/role';
  static String adminToggleBan(int id)   => '/api/admin/users/$id/ban';
  static String adminDeleteMedia(int id) => '/api/admin/media/$id';
}
