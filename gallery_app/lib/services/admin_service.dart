import '../config/api_config.dart';
import '../models/admin_models.dart';
import 'api_service.dart';

class AdminService {
  // ── Stats ──────────────────────────────────────────────────────────────────
  static Future<AdminStats> getStats() async {
    final res = await ApiService.dio.get(ApiConfig.adminStats);
    return AdminStats.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Users ──────────────────────────────────────────────────────────────────
  static Future<PagedResult<AdminUser>> listUsers({
    int    page   = 1,
    int    limit  = 20,
    String search = '',
  }) async {
    final res = await ApiService.dio.get(
      ApiConfig.adminUsers,
      queryParameters: {
        'page':   page,
        'limit':  limit,
        if (search.isNotEmpty) 'search': search,
      },
    );
    final data  = res.data as Map<String, dynamic>;
    final items = (data['users'] as List)
        .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagedResult(
      items:      items,
      total:      data['total']      as int,
      page:       data['page']       as int,
      totalPages: data['totalPages'] as int,
    );
  }

  static Future<void> deleteUser(int userId) async {
    await ApiService.dio.delete(ApiConfig.adminDeleteUser(userId));
  }

  static Future<AdminUser> updateRole(int userId, String role) async {
    final res = await ApiService.dio.patch(
      ApiConfig.adminUpdateRole(userId),
      data: {'role': role},
    );
    return AdminUser(
      userId:   res.data['user_id'] as int,
      email:    '',
      role:     res.data['role']    as String,
      isBanned: false,
    );
  }

  static Future<void> toggleBan(int userId, {required bool ban}) async {
    await ApiService.dio.patch(
      ApiConfig.adminToggleBan(userId),
      data: {'ban': ban},
    );
  }

  // ── Media ──────────────────────────────────────────────────────────────────
  static Future<PagedResult<AdminMediaItem>> listMedia({
    int    page   = 1,
    int    limit  = 20,
    String search = '',
  }) async {
    final res = await ApiService.dio.get(
      ApiConfig.adminMedia,
      queryParameters: {
        'page':   page,
        'limit':  limit,
        if (search.isNotEmpty) 'search': search,
      },
    );
    final data  = res.data as Map<String, dynamic>;
    final items = (data['media'] as List)
        .map((e) => AdminMediaItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagedResult(
      items:      items,
      total:      data['total']      as int,
      page:       data['page']       as int,
      totalPages: data['totalPages'] as int,
    );
  }

  static Future<void> deleteMedia(int mediaId) async {
    await ApiService.dio.delete(ApiConfig.adminDeleteMedia(mediaId));
  }

  // ── Audit logs ─────────────────────────────────────────────────────────────
  static Future<PagedResult<AuditLogEntry>> getAuditLogs({
    int page  = 1,
    int limit = 50,
  }) async {
    final res = await ApiService.dio.get(
      ApiConfig.adminAuditLogs,
      queryParameters: {'page': page, 'limit': limit},
    );
    final data  = res.data as Map<String, dynamic>;
    final items = (data['logs'] as List)
        .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagedResult(
      items:      items,
      total:      data['total']      as int,
      page:       data['page']       as int,
      totalPages: data['totalPages'] as int,
    );
  }
}
