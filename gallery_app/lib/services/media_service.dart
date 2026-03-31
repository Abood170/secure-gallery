import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/media_item.dart';
import 'api_service.dart';

class DownloadResult {
  final Uint8List ciphertext;
  final String algo;
  final String iv;
  final String filename;

  const DownloadResult({
    required this.ciphertext,
    required this.algo,
    required this.iv,
    required this.filename,
  });
}

class MediaService {
  static Future<List<MediaItem>> listMedia() async {
    final res  = await ApiService.dio.get(ApiConfig.listMedia);
    final list = res.data['media'] as List;
    return list
        .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<int> uploadMedia({
    required Uint8List ciphertext,
    required String filename,
    required String algo,
    required String iv,
  }) async {
    final formData = FormData.fromMap({
      'file':     MultipartFile.fromBytes(ciphertext, filename: 'encrypted.bin'),
      'filename': filename,
      'algo':     algo,
      'iv':       iv,
    });
    final res = await ApiService.dio.post(
      ApiConfig.uploadMedia,
      data: formData,
    );
    return res.data['media_id'] as int;
  }

  static Future<void> deleteMedia(int mediaId) async {
    await ApiService.dio.delete(ApiConfig.deleteMedia(mediaId));
  }

  /// Download own encrypted image (owner only).
  static Future<DownloadResult> downloadMedia(int mediaId) async {
    final res = await ApiService.dio.get(
      ApiConfig.downloadMedia(mediaId),
      options: Options(responseType: ResponseType.bytes),
    );
    return _parseDownloadResponse(res);
  }

  /// Download an encrypted image shared with the authenticated user.
  static Future<DownloadResult> downloadShared(int shareId) async {
    final res = await ApiService.dio.get(
      ApiConfig.downloadShared(shareId),
      options: Options(responseType: ResponseType.bytes),
    );
    return _parseDownloadResponse(res);
  }

  static DownloadResult _parseDownloadResponse(Response res) {
    return DownloadResult(
      ciphertext: Uint8List.fromList(res.data as List<int>),
      algo:       res.headers['x-algo']?.first ?? '',
      iv:         res.headers['x-iv']?.first ?? '',
      filename:   Uri.decodeComponent(res.headers['x-filename']?.first ?? ''),
    );
  }
}
