import 'package:flutter/foundation.dart';
import '../models/media_item.dart';
import '../models/share_item.dart';
import '../services/media_service.dart';
import '../services/share_service.dart';

class GalleryProvider extends ChangeNotifier {
  List<MediaItem> _mediaList = [];
  List<ShareItem> _inbox     = [];
  bool _loading    = false;
  String? _error;

  List<MediaItem> get mediaList => List.unmodifiable(_mediaList);
  List<ShareItem> get inbox     => List.unmodifiable(_inbox);
  bool get loading  => _loading;
  String? get error => _error;

  Future<void> loadMedia() async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      _mediaList = await MediaService.listMedia();
    } catch (_) {
      _error = 'Failed to load gallery.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadInbox() async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      _inbox = await ShareService.getInbox();
    } catch (_) {
      _error = 'Failed to load inbox.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void prependMedia(MediaItem item) {
    _mediaList = [item, ..._mediaList];
    notifyListeners();
  }

  void removeMedia(int mediaId) {
    _mediaList = _mediaList.where((m) => m.mediaId != mediaId).toList();
    notifyListeners();
  }
}
