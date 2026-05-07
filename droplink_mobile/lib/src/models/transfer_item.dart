enum TransferStatus { waiting, offering, transferring, completed, failed, cancelled }

class TransferItem {
  const TransferItem({
    required this.id,
    required this.filename,
    required this.totalBytes,
    required this.sentBytes,
    required this.speedBytesPerSecond,
    required this.status,
    this.error,
  });

  final String id;
  final String filename;
  final int totalBytes;
  final int sentBytes;
  final double speedBytesPerSecond;
  final TransferStatus status;
  final String? error;

  double get progress => totalBytes == 0 ? 0 : sentBytes / totalBytes;

  Duration? get eta {
    if (speedBytesPerSecond <= 0 || sentBytes >= totalBytes) return null;
    return Duration(seconds: ((totalBytes - sentBytes) / speedBytesPerSecond).ceil());
  }

  TransferItem copyWith({
    int? sentBytes,
    double? speedBytesPerSecond,
    TransferStatus? status,
    String? error,
  }) {
    return TransferItem(
      id: id,
      filename: filename,
      totalBytes: totalBytes,
      sentBytes: sentBytes ?? this.sentBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
