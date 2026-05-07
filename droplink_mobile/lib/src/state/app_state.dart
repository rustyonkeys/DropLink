import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/nearby_device.dart';
import '../models/transfer_item.dart';
import '../models/transfer_offer.dart';
import '../services/device_identity.dart';
import '../services/discovery_service.dart';
import '../services/file_transfer_service.dart';
import '../services/permission_service.dart';
import '../services/receiver_server.dart';

class AppState extends ChangeNotifier {
  AppState()
      : identity = DeviceIdentity(),
        permissionService = PermissionService() {
    discoveryService = DiscoveryService(identity);
    transferService = FileTransferService(identity);
    receiverServer = ReceiverServer(
      onOffer: _handleOffer,
      onProgress: _handleReceiveProgress,
    );
  }

  final DeviceIdentity identity;
  final PermissionService permissionService;
  late final DiscoveryService discoveryService;
  late final FileTransferService transferService;
  late final ReceiverServer receiverServer;

  final devices = <String, NearbyDevice>{};
  final transfers = <TransferItem>[];

  StreamSubscription? _deviceSubscription;
  TransferOffer? pendingOffer;
  Completer<bool>? _offerCompleter;

  Future<void> start() async {
    await permissionService.requestStartupPermissions();
    await receiverServer.start();
    _deviceSubscription = discoveryService.devices.listen((value) {
      devices
        ..clear()
        ..addAll(value);
      notifyListeners();
    });
    await discoveryService.start();
  }

  Future<void> sendTo(NearbyDevice device) async {
    await transferService.pickAndSend(device, _upsertTransfer);
  }

  void acceptPendingOffer() {
    _offerCompleter?.complete(true);
    pendingOffer = null;
    _offerCompleter = null;
    notifyListeners();
  }

  void declinePendingOffer() {
    _offerCompleter?.complete(false);
    pendingOffer = null;
    _offerCompleter = null;
    notifyListeners();
  }

  Future<bool> _handleOffer(TransferOffer offer) {
    pendingOffer = offer;
    _offerCompleter = Completer<bool>();
    notifyListeners();
    return _offerCompleter!.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        pendingOffer = null;
        _offerCompleter = null;
        notifyListeners();
        return false;
      },
    );
  }

  void _handleReceiveProgress(String transferId, int receivedBytes) {
    final existingIndex = transfers.indexWhere((item) => item.id == transferId);
    if (existingIndex == -1) {
      transfers.insert(
        0,
        TransferItem(
          id: transferId,
          filename: pendingOffer?.filename ?? 'Incoming file',
          totalBytes: pendingOffer?.size ?? 0,
          sentBytes: receivedBytes,
          speedBytesPerSecond: 0,
          status: TransferStatus.transferring,
        ),
      );
    } else {
      final current = transfers[existingIndex];
      final done = current.totalBytes > 0 && receivedBytes >= current.totalBytes;
      transfers[existingIndex] = current.copyWith(
        sentBytes: receivedBytes,
        status: done ? TransferStatus.completed : TransferStatus.transferring,
      );
    }
    notifyListeners();
  }

  void _upsertTransfer(TransferItem item) {
    final index = transfers.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      transfers.insert(0, item);
    } else {
      transfers[index] = item;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    discoveryService.dispose();
    receiverServer.stop();
    super.dispose();
  }
}
