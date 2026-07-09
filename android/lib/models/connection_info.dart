class ConnectionInfo {
  final String id;
  final String ip;
  final String name;
  final String status;
  final String resolution;
  final bool available;
  final int port;

  const ConnectionInfo({
    required this.id,
    required this.ip,
    required this.name,
    required this.status,
    required this.resolution,
    this.available = true,
    this.port = 80,
  });

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) => ConnectionInfo(
    id: json['id'] ?? '',
    ip: json['ip'] ?? '',
    name: json['name'] ?? 'Projetor',
    status: json['status'] ?? 'offline',
    resolution: json['resolution'] ?? '1360x768',
    available: json['available'] ?? false,
    port: json['port'] ?? 80,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ip': ip,
    'name': name,
    'status': status,
    'resolution': resolution,
    'available': available,
    'port': port,
  };
}
