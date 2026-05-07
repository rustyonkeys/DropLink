import 'package:flutter/material.dart';

import '../models/transfer_item.dart';

class TransferTile extends StatelessWidget {
  const TransferTile({super.key, required this.item});

  final TransferItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusText = switch (item.status) {
      TransferStatus.waiting => 'Waiting',
      TransferStatus.offering => 'Waiting for receiver',
      TransferStatus.transferring => _progressText(),
      TransferStatus.completed => 'Completed',
      TransferStatus.failed => item.error ?? 'Failed',
      TransferStatus.cancelled => 'Cancelled',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: item.status == TransferStatus.completed ? Colors.green.withValues(alpha: 0.18) : scheme.primaryContainer,
            child: Icon(item.status == TransferStatus.completed ? Icons.check_rounded : Icons.insert_drive_file_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: item.status == TransferStatus.completed ? 1 : item.progress),
                const SizedBox(height: 6),
                Text(statusText, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _progressText() {
    final speed = item.speedBytesPerSecond / (1024 * 1024);
    final percent = (item.progress * 100).clamp(0, 100);
    final eta = item.eta;
    final etaText = eta == null ? '' : ' - ${eta.inSeconds}s left';
    return '${percent.toStringAsFixed(1)}% at ${speed.toStringAsFixed(2)} MB/s$etaText';
  }
}
