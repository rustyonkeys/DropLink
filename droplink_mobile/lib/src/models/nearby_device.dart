class NearbyDevice {
  const NearbyDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.host,
    required this.port,
    required this.lastSeen,
  });

  final String id;
  final String name;
  final String platform;
  final String host;
  final int port;
  final DateTime lastSeen;

  String get baseUrl => 'http://$host:$port';

  factory NearbyDevice.fromJson(Map<String, dynamic> json, String fallbackHost) {
    return NearbyDevice(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Unknown device',
      platform: (json['platform'] as String?) ?? 'unknown',
      host: (json['host'] as String?) ?? fallbackHost,
      port: json['port'] as int,
      lastSeen: DateTime.now(),
    );
  }
}
