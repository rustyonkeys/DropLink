import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/nearby_device.dart';
import 'device_identity.dart';

typedef DeviceMap = Map<String, NearbyDevice>;

class DiscoveryService {
  DiscoveryService(this.identity);

  static const int discoveryPort = 45870;
  static const int httpPort = 45872;
  static const Duration announceInterval = Duration(seconds: 2);
  static const Duration deviceTimeout = Duration(seconds: 8);

  final DeviceIdentity identity;
  final _devices = <String, NearbyDevice>{};
  final _controller = StreamController<DeviceMap>.broadcast();

  RawDatagramSocket? _announceSocket;
  RawDatagramSocket? _listenSocket;
  Timer? _announceTimer;
  Timer? _cleanupTimer;
  String _host = '127.0.0.1';

  Stream<DeviceMap> get devices => _controller.stream;

  Future<void> start() async {
    _host = await _localIpAddress();
    _listenSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort, reuseAddress: true);
    _listenSocket!.listen(_handleSocketEvent);

    _announceSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _announceSocket!.broadcastEnabled = true;

    _announceTimer = Timer.periodic(announceInterval, (_) => announce());
    _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) => _removeStaleDevices());
    announce();
  }

  void announce() {
    final payload = jsonEncode({
      'app': 'droplink',
      'version': 1,
      'id': identity.id,
      'name': identity.name,
      'platform': identity.platform,
      'host': _host,
      'port': httpPort,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    _announceSocket?.send(utf8.encode(payload), InternetAddress('255.255.255.255'), discoveryPort);
  }

  void _handleSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _listenSocket?.receive();
    if (datagram == null) return;

    try {
      final json = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      if (json['app'] != 'droplink' || json['id'] == identity.id) return;
      final device = NearbyDevice.fromJson(json, datagram.address.address);
      _devices[device.id] = device;
      _controller.add(Map.unmodifiable(_devices));
    } catch (_) {
      // Ignore unrelated local UDP packets.
    }
  }

  void _removeStaleDevices() {
    final now = DateTime.now();
    _devices.removeWhere((_, device) => now.difference(device.lastSeen) > deviceTimeout);
    _controller.add(Map.unmodifiable(_devices));
  }

  Future<void> dispose() async {
    _announceTimer?.cancel();
    _cleanupTimer?.cancel();
    _announceSocket?.close();
    _listenSocket?.close();
    await _controller.close();
  }

  Future<String> _localIpAddress() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) return address.address;
      }
    }
    return '127.0.0.1';
  }
}
