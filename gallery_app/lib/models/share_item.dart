class ShareItem {
  final int shareId;
  final int mediaId;
  final String filename;
  final String algo;
  final String iv;
  final String senderEmail;
  final String? expiresAt;

  const ShareItem({
    required this.shareId,
    required this.mediaId,
    required this.filename,
    required this.algo,
    required this.iv,
    required this.senderEmail,
    this.expiresAt,
  });

  factory ShareItem.fromJson(Map<String, dynamic> json) {
    final media  = json['media']  as Map<String, dynamic>;
    final sender = json['sender'] as Map<String, dynamic>;
    return ShareItem(
      shareId:     json['share_id'] as int,
      mediaId:     media['media_id'] as int,
      filename:    media['filename'] as String,
      algo:        media['algo'] as String,
      iv:          media['iv'] as String,
      senderEmail: sender['email'] as String,
      expiresAt:   json['expires_at'] as String?,
    );
  }
}
