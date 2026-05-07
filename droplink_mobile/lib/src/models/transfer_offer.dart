class TransferOffer {
  const TransferOffer({
    required this.transferId,
    required this.senderId,
    required this.senderName,
    required this.filename,
    required this.size,
    required this.mimeType,
  });

  final String transferId;
  final String senderId;
  final String senderName;
  final String filename;
  final int size;
  final String mimeType;

  factory TransferOffer.fromJson(Map<String, dynamic> json) {
    return TransferOffer(
      transferId: json['transfer_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      filename: json['filename'] as String,
      size: json['size'] as int,
      mimeType: (json['mime_type'] as String?) ?? 'application/octet-stream',
    );
  }
}
