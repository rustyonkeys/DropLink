import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transfer_item.dart';
import '../state/app_state.dart';
import '../widgets/transfer_tile.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final transfers = state.transfers;
    final canClear = transfers.any(
      (item) => item.status == TransferStatus.completed || item.status == TransferStatus.failed || item.status == TransferStatus.cancelled,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        actions: [
          IconButton(
            onPressed: canClear ? () => context.read<AppState>().clearTransferHistory() : null,
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear finished transfers',
          ),
        ],
      ),
      body: transfers.isEmpty
          ? const _EmptyHistory()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: transfers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => TransferTile(item: transfers[index]),
            ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No transfer history yet.',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
