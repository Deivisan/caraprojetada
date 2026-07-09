import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:caraprojetada/models/connection_info.dart';

class ApiService {
  final String host;
  final int port;
  static const int defaultPort = 80;

  /// faixa fixa de ips da rede do cetens (172.17.7.50 a 172.17.7.60)
  static const List<String> knownIps = [
    '172.17.7.50', '172.17.7.51', '172.17.7.52', '172.17.7.53',
    '172.17.7.54', '172.17.7.55', '172.17.7.56', '172.17.7.57',
    '172.17.7.58', '172.17.7.59', '172.17.7.60',
  ];

  ApiService({this.host = '', this.port = defaultPort});

  String get baseUrl => host.isEmpty ? '' : 'http://$host:$port';
  bool get isConfigured => host.isNotEmpty && port > 0;

  /// descobre boxes escaneando a faixa fixa 172.17.7.50-60
  Future<List<String>> discoverBoxes({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final candidates = <String>[];
    final futures = <Future<String?>>[];

    // sempre escaneia a faixa conhecida primeiro
    for (final ip in knownIps) {
      futures.add(_checkHost(ip, timeout));
    }

    // tambem tenta subnets detectadas
    try {
      final subnets = await _guessLocalSubnets();
      for (final subnet in subnets) {
        for (int i = 1; i <= 20; i++) {
          futures.add(_checkHost('$subnet.$i', timeout));
        }
      }
    } catch (_) {}

    final results = await Future.wait(futures, eagerError: false);
    for (final ip in results) {
      if (ip != null && !candidates.contains(ip)) {
        candidates.add(ip);
      }
    }

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
      throw Exception(_tryParseError(resp.body));
    }
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  /// conecta ao projetor — sem pin para android (box ignora)
  Future<Map<String, dynamic>> connectMobile({
    required String deviceIp,
    String? pin,
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
            'orientation': orientation,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 409) {
      throw Exception('projetor ocupado');
    }
    if (resp.statusCode != 200) {
      throw Exception(_tryParseError(resp.body));
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

  Future<void> forceDisconnect() async {
    if (!isConfigured) return;
    try {
      await http
          .post(Uri.parse('$baseUrl/api/v1/force-disconnect'))
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  // === PROJEÇÃO DE ARQUIVOS (PDF) ===

  /// envia um arquivo (pdf) para a box projetar
  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    if (!isConfigured) throw Exception('ip da box nao configurado');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/upload'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) throw Exception(_tryParseError(resp.body));
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  /// inicia projeção do arquivo enviado
  Future<void> projectStart({int page = 1}) async {
    if (!isConfigured) return;
    try {
      await http
          .post(Uri.parse('$baseUrl/api/v1/project-start'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'page': page}))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// próxima página
  Future<void> projectNext() async {
    if (!isConfigured) return;
    try {
      await http
          .post(Uri.parse('$baseUrl/api/v1/project-next'))
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  /// página anterior
  Future<void> projectPrev() async {
    if (!isConfigured) return;
    try {
      await http
          .post(Uri.parse('$baseUrl/api/v1/project-prev'))
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  /// para a projeção
  Future<void> projectStop() async {
    if (!isConfigured) return;
    try {
      await http
          .post(Uri.parse('$baseUrl/api/v1/project-stop'))
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
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

  Future<String?> _checkHost(String ip, Duration timeout) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = timeout
        ..autoUncompress = false;
      try {
        final request = await client
            .getUrl(Uri.parse('http://$ip/api/v1/status'))
            .timeout(timeout);
        final response = await request.close().timeout(timeout);
        if (response.statusCode == 200) return ip;
      } finally {
        client.close(force: true);
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>> _guessLocalSubnets() async {
    final result = <String>['172.17.7']; // sempre inclui a faixa do cetens
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
    } catch (_) {}
    return result.toSet().toList();
  }
}

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
