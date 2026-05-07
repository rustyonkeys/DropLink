import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transfer_offer.dart';
import '../state/app_state.dart';

class PendingOfferSheet extends StatelessWidget {
  const PendingOfferSheet({super.key, required this.offer});

  final TransferOffer offer;

  @override
  Widget build(BuildContext context) {
    final sizeMb = offer.size / (1024 * 1024);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 26, child: Icon(Icons.download_rounded)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Accept file transfer?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    Text('${offer.senderName} wants to send a file'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(offer.filename, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${sizeMb.toStringAsFixed(2)} MB - ${offer.mimeType}'),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.read<AppState>().declinePendingOffer();
                    Navigator.pop(context);
                  },
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    context.read<AppState>().acceptPendingOffer();
                    Navigator.pop(context);
                  },
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
