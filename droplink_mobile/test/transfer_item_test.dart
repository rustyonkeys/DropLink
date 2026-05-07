import 'package:droplink_mobile/src/models/transfer_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates transfer progress and ETA', () {
    const item = TransferItem(
      id: 'transfer-1',
      filename: 'video.mp4',
      totalBytes: 1000,
      sentBytes: 250,
      speedBytesPerSecond: 250,
      status: TransferStatus.transferring,
    );

    expect(item.progress, 0.25);
    expect(item.eta, const Duration(seconds: 3));
  });
}
