import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  final String host; // ex: "192.168.1.100" — sem protocolo nem porta
  final int port;
  static const int defaultPort = 80;

  ApiService({this.host = '', this.port = defaultPort});

  String get baseUrl => host.isEmpty ? '' : 'http://$host:$port';

  bool get isConfigured => host.isNotEmpty && port > 0;

  /// tenta detectar boxes automaticamente na rede local
  /// escaneia faixas comuns de IP privado (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
  /// e verifica qual responde na porta 80
  Future<List<String>> discoverBoxes({Duration timeout = const Duration(seconds: 8)}) async {
    final candidates = <String>[];
    final subnets = _guessLocalSubnets();

    for (final subnet in subnets) {
      // escaneia apenas até 20 hosts por subnet para não travar
      final futures = <Future<void>>[];
      for (int i = 1; i <= 20; i++) {
        final ip = '$subnet.$i';
        futures.add(_checkHost(ip, timeout));
      }
      await Future.wait(futures);
    }

    // tenta também ler do zeroconf/mDNS (se o pacote estiver instalado)
    try {
      final mdnsHosts = await _discoverViaMdns();
      for (final h in mdnsHosts) {
        if (!candidates.contains(h)) candidates.add(h);
      }
    } catch (_) {
      // silencioso — mDNS é opcional
    }

    return candidates;
  }

  Future<List<ConnectionInfo>> getDevices() async {
    if (!isConfigured) throw Exception('IP da box nao configurado');
    final resp = await http
        .get(Uri.parse('$baseUrl/api/v1/devices'))
        .timeout(const Duration(seconds: 5));
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
    if (!isConfigured) throw Exception('IP da box nao configurado');
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
    if (resp.statusCode != 200) throw Exception('falha no registro');
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> connectMobile({
    required String deviceIp,
    required String pin,
    String orientation = 'retrato',
  }) async {
    if (!isConfigured) throw Exception('IP da box nao configurado');
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
    if (resp.statusCode != 200) {
      final err = json.decode(resp.body);
      throw Exception(err['error'] ?? 'falha na conexao');
    }
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStatus() async {
    if (!isConfigured) throw Exception('IP da box nao configurado');
    final resp =
        await http.get(Uri.parse('$baseUrl/api/v1/status')).timeout(
              const Duration(seconds: 5),
            );
    if (resp.statusCode != 200) throw Exception('falha no status');
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  // ---- internos ----

  List<String> _guessLocalSubnets() {
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
            // assume máscara /24 comum
            final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
            final first = int.tryParse(parts[0]) ?? 0;
            if (first == 192) result.add('192.168.${parts[1]}.${parts[2]}');
            else if (first == 10) result.add('10.${parts[1]}.${parts[2]}');
            else if (first == 172 && int.tryParse(parts[1]) != null && (int.parse(parts[1]) >= 16 && int.parse(parts[1]) <= 31)) {
              result.add('172.${parts[1]}.${parts[2]}');
            }
          }
        }
      }
    } catch (_) {
      // fallback para subnets comuns em redes domésticas
      result
        ..add('192.168.1')
        ..add('192.168.0')
        ..add('10.0.0');
    }
    // remove duplicatas mantendo ordem
    return result.toSet().toList();
  }

  Future<void> _checkHost(String ip, Duration timeout) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = timeout;
      final request = await client.getUrl(Uri.parse('http://$ip/api/v1/status'));
      final response = await request.close().timeout(timeout);
      client.close();
      // não brincamos com o resultado aqui, só marca que o host responde
    } catch (_) {
      // host offline — silencioso
    }
  }

  Future<List<String>> _discoverViaMdns() async {
    // placeholder: integração com pacote mdns_plugin vai aqui
    // por enquanto retorna vazio
    return <String>[];
  }
}

// helper para obter IP local do dispositivo (para registrar no flask)
Future<String> getLocalIpAddress() async {
  try {
    final interfaces = await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4);
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.address.startsWith('127.')) return addr.address;
      }
    }
  } catch (_) {}
  return '0.0.0.0';
}
