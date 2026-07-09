import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://172.17.7.51:80';

  Future<List<ConnectionInfo>> getDevices() async {
    final resp = await http.get(Uri.parse('$_baseUrl/api/v1/devices')).timeout(
      const Duration(seconds: 5),
    );
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
    final resp = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/register'),
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
    final resp = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/connect-mobile'),
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
    final resp = await http.get(Uri.parse('$_baseUrl/api/v1/status')).timeout(
      const Duration(seconds: 5),
    );
    if (resp.statusCode != 200) throw Exception('falha no status');
    return json.decode(resp.body) as Map<String, dynamic>;
  }
}
