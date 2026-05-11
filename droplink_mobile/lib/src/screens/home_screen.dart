import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/nearby_device.dart';
import '../state/app_state.dart';
import 'history_screen.dart';
import '../widgets/device_card.dart';
import '../widgets/pending_offer_sheet.dart';
import '../widgets/scanning_pulse.dart';
import '../widgets/transfer_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _sheetVisible = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _showOfferIfNeeded(state);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0EA5E9), Color(0xFF4F46E5), Color(0xFF111827)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DropLink',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          SizedBox(height: 4),
                          Text('Local sharing, no cloud', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
                        );
                      },
                      icon: const Icon(Icons.history_rounded),
                      tooltip: 'Transfer history',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: _DiscoveryHeader(count: state.devices.length)),
                          const SliverToBoxAdapter(child: SizedBox(height: 14)),
                          if (state.devices.isEmpty)
                            const SliverToBoxAdapter(child: ScanningPulse())
                          else
                            SliverGrid.builder(
                              itemCount: state.devices.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.95,
                              ),
                              itemBuilder: (context, index) {
                                final device = state.devices.values.elementAt(index);
                                return DeviceCard(device: device, onSend: () => _send(context, device));
                              },
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          SliverToBoxAdapter(
                            child: Text(
                              'Transfers',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          if (state.transfers.isEmpty)
                            const SliverToBoxAdapter(child: _EmptyTransfers())
                          else
                            SliverList.separated(
                              itemCount: state.transfers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => TransferTile(item: state.transfers[index]),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send(BuildContext context, NearbyDevice device) async {
    await context.read<AppState>().sendTo(device);
  }

  void _showOfferIfNeeded(AppState state) {
    if (state.pendingOffer == null || _sheetVisible) return;
    _sheetVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => PendingOfferSheet(offer: state.pendingOffer!),
      );
      _sheetVisible = false;
    });
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Nearby Devices',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Chip(label: Text('$count found')),
      ],
    );
  }
}

class _EmptyTransfers extends StatelessWidget {
  const _EmptyTransfers();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      ),
      child: const Text('Sent and received files will appear here.'),
    );
  }
}
