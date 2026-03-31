import 'package:flutter/foundation.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';

class AdminProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  AdminStats? stats;

  // Users tab
  List<AdminUser> users      = [];
  int  userPage              = 1;
  int  userTotalPages        = 1;
  int  userTotal             = 0;
  String userSearch          = '';

  // Media tab
  List<AdminMediaItem> media = [];
  int  mediaPage             = 1;
  int  mediaTotalPages       = 1;
  int  mediaTotal            = 0;
  String mediaSearch         = '';

  // Audit logs tab
  List<AuditLogEntry> auditLogs = [];
  int  logPage               = 1;
  int  logTotalPages         = 1;
  int  logTotal              = 0;

  bool    loading    = false;
  String? error;

  // ── Load all (called on init) ──────────────────────────────────────────────
  Future<void> loadAll() async {
    loading = true;
    error   = null;
    notifyListeners();
    try {
      await Future.wait([
        _fetchStats(),
        _fetchUsers(),
        _fetchMedia(),
        _fetchLogs(),
      ]);
    } catch (_) {
      error = 'Failed to load admin data.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  Future<void> _fetchStats() async {
    stats = await AdminService.getStats();
  }

  Future<void> refreshStats() async {
    try {
      stats = await AdminService.getStats();
      notifyListeners();
    } catch (_) {}
  }

  // ── Users ──────────────────────────────────────────────────────────────────
  Future<void> _fetchUsers() async {
    final result = await AdminService.listUsers(
      page:   userPage,
      search: userSearch,
    );
    users          = result.items;
    userTotal      = result.total;
    userTotalPages = result.totalPages;
    userPage       = result.page;
  }

  Future<void> loadUsers({int? page, String? search}) async {
    if (page   != null) userPage   = page;
    if (search != null) userSearch = search;
    loading = true;
    notifyListeners();
    try {
      await _fetchUsers();
    } catch (_) {
      error = 'Failed to load users.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> deleteUser(int userId) async {
    try {
      await AdminService.deleteUser(userId);
      users.removeWhere((u) => u.userId == userId);
      userTotal = (userTotal - 1).clamp(0, double.maxFinite.toInt());
      notifyListeners();
      await refreshStats();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateRole(int userId, String role) async {
    try {
      await AdminService.updateRole(userId, role);
      final idx = users.indexWhere((u) => u.userId == userId);
      if (idx != -1) {
        users[idx] = users[idx].copyWith(role: role);
        notifyListeners();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> toggleBan(int userId, {required bool ban}) async {
    try {
      await AdminService.toggleBan(userId, ban: ban);
      final idx = users.indexWhere((u) => u.userId == userId);
      if (idx != -1) {
        users[idx] = users[idx].copyWith(isBanned: ban);
        notifyListeners();
      }
      await refreshStats();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Media ──────────────────────────────────────────────────────────────────
  Future<void> _fetchMedia() async {
    final result = await AdminService.listMedia(
      page:   mediaPage,
      search: mediaSearch,
    );
    media          = result.items;
    mediaTotal     = result.total;
    mediaTotalPages = result.totalPages;
    mediaPage      = result.page;
  }

  Future<void> loadMedia({int? page, String? search}) async {
    if (page   != null) mediaPage   = page;
    if (search != null) mediaSearch = search;
    loading = true;
    notifyListeners();
    try {
      await _fetchMedia();
    } catch (_) {
      error = 'Failed to load media.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> deleteMedia(int mediaId) async {
    try {
      await AdminService.deleteMedia(mediaId);
      media.removeWhere((m) => m.mediaId == mediaId);
      mediaTotal = (mediaTotal - 1).clamp(0, double.maxFinite.toInt());
      notifyListeners();
      await refreshStats();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Audit logs ─────────────────────────────────────────────────────────────
  Future<void> _fetchLogs() async {
    final result = await AdminService.getAuditLogs(page: logPage);
    auditLogs    = result.items;
    logTotal     = result.total;
    logTotalPages = result.totalPages;
    logPage      = result.page;
  }

  Future<void> loadLogs({int? page}) async {
    if (page != null) logPage = page;
    loading = true;
    notifyListeners();
    try {
      await _fetchLogs();
    } catch (_) {
      error = 'Failed to load audit logs.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
