class MediaItem {
  final int mediaId;
  final String filename;
  final String algo;
  final String iv;

  const MediaItem({
    required this.mediaId,
    required this.filename,
    required this.algo,
    required this.iv,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        mediaId: json['media_id'] as int,
        filename: json['filename'] as String,
        algo: json['algo'] as String,
        iv: json['iv'] as String,
      );
}
