import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:caraprojetada/models/connection_info.dart';

class ApiService {
  final String host;
  final int port;
  static const int defaultPort = 80;

  ApiService({this.host = '', this.port = defaultPort});

  String get baseUrl => host.isEmpty ? '' : 'http://$host:$port';
  bool get isConfigured => host.isNotEmpty && port > 0;

  /// descobre boxes na rede local escaneando subnets comuns
  Future<List<String>> discoverBoxes({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final candidates = <String>[];
    final subnets = await _guessLocalSubnets();

    for (final subnet in subnets) {
      final futures = <Future<String?>>[];
      for (int i = 1; i <= 20; i++) {
        final ip = '$subnet.$i';
        futures.add(_checkHost(ip, timeout));
      }
      final results = await Future.wait(futures, eagerError: false);
      for (final ip in results) {
        if (ip != null && !candidates.contains(ip)) {
          candidates.add(ip);
        }
      }
    }

    // tenta mDNS também
    try {
      final mdnsHosts = await _discoverViaMdns();
      for (final h in mdnsHosts) {
        if (!candidates.contains(h)) candidates.add(h);
      }
    } catch (_) {}

    return candidates;
  }

  Future<List<ConnectionInfo>> getDevices() async {
    if (!isConfigured) throw Exception('ip da box nao configurado');
    final resp = await http
        .get(Uri.parse('$baseUrl/api/v1/devices'))
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) throw Exception('falha ao listar boxes');
    final data = json.decode(resp.body) as Map<String, dynamic>;
    return (data['boxes'] as List)
        .map((b) => ConnectionInfo.fromJson(b))
        .toList();
  }

  Future<Map<String, dynamic>> registerDevice({
    required String deviceIp,
    required String deviceName,
    int port = 5900,
    String orientation = 'retrato',
  }) async {
    if (!isConfigured) throw Exception('ip da box nao configurado');
    final resp = await http
        .post(
          Uri.parse('$baseUrl/api/v1/register'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'device_ip': deviceIp,
            'device_name': deviceName,
            'port': port.toString(),
            'orientation': orientation,
            'device_type': 'android',
          }),
        )
        .timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      final err = _tryParseError(resp.body);
      throw Exception(err);
    }
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> connectMobile({
    required String deviceIp,
    required String pin,
    String orientation = 'retrato',
  }) async {
    if (!isConfigured) throw Exception('ip da box nao configurado');
    final resp = await http
        .post(
          Uri.parse('$baseUrl/api/v1/connect-mobile'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'device_ip': deviceIp,
            'port': '5900',
            'pin': pin,
            'orientation': orientation,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 409) {
      throw Exception('projetor ocupado por outro usuario');
    }
    if (resp.statusCode != 200) {
      final err = _tryParseError(resp.body);
      throw Exception(err);
    }
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStatus() async {
    if (!isConfigured) throw Exception('ip da box nao configurado');
    final resp = await http
        .get(Uri.parse('$baseUrl/api/v1/status'))
        .timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) throw Exception('falha no status');
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  /// libera a sessao na box (força desconexao do viewer remoto)
  Future<void> forceDisconnect() async {
    if (!isConfigured) return;
    try {
      await http
          .post(Uri.parse('$baseUrl/api/v1/force-disconnect'))
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // falha silenciosa — o disconnect local já é o suficiente
    }
  }

  // ---- helpers ----

  String _tryParseError(String body) {
    try {
      final err = json.decode(body);
      return err['error'] ?? err['message'] ?? 'erro desconhecido';
    } catch (_) {
      return body.length > 100 ? body.substring(0, 100) : body;
    }
  }

  /// verifica se um host responde na porta 80 com /api/v1/status
  /// retorna o ip se responder, null caso contrario
  Future<String?> _checkHost(String ip, Duration timeout) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = timeout
        ..autoUncompress = false;
      try {
        final request = await client.getUrl(
          Uri.parse('http://$ip/api/v1/status'),
        ).timeout(timeout);
        final response = await request.close().timeout(timeout);
        if (response.statusCode == 200) return ip;
      } finally {
        client.close(force: true);
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>> _guessLocalSubnets() async {
    final result = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: true,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            final first = int.tryParse(parts[0]) ?? 0;
            if (first == 192) {
              result.add('192.168.${parts[1]}');
            } else if (first == 10) {
              result.add('10.${parts[1]}');
            } else if (first == 172) {
              final second = int.tryParse(parts[1]) ?? 0;
              if (second >= 16 && second <= 31) {
                result.add('172.${parts[1]}');
              }
            }
          }
        }
      }
    } catch (_) {
      result
        ..add('192.168.1')
        ..add('192.168.0')
        ..add('10.0.0');
    }
    return result.toSet().toList();
  }

  Future<List<String>> _discoverViaMdns() async {
    return <String>[];
  }
}

/// obtem o ip local do dispositivo (primeiro ipv4 nao loopback)
Future<String> getLocalIpAddress() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.address.startsWith('127.')) return addr.address;
      }
    }
  } catch (_) {}
  return '0.0.0.0';
}
