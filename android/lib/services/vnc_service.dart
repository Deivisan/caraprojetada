import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';

class VncService {
  static const _methodChannel = MethodChannel('caraprojetada/vnc');
  static bool _running = false;

  Future<bool> startVncServer({
    required String password,
    String port = '5900',
    bool bindInterface = false,
  }) async {
    if (_running) return true;
    try {
      final result = await _methodChannel.invokeMethod('startVnc', {
        'password': password,
        'port': port,
        'bindInterface': bindInterface,
      });
      _running = result == true;
      return _running;
    } on PlatformException catch (e) {
      throw Exception('erro ao iniciar VNC: ${e.message}');
    }
  }

  Future<void> stopVncServer() async {
    try {
      await _methodChannel.invokeMethod('stopVnc');
      _running = false;
    } on PlatformException catch (e) {
      throw Exception('erro ao parar VNC: ${e.message}');
    }
  }

  Future<bool> isRunning() async {
    try {
      final result = await _methodChannel.invokeMethod('isRunning');
      _running = result == true;
      return _running;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPermissions() async {
    final result = await [
      Permission.mediaProjection,
      Permission.systemAlertWindow,
      Permission.accessibilityService,
      Permission.notification,
      Permission.wakeLock,
    ].request();

    final granted = result.values.every((s) => s.isGranted);
    if (!granted) {
      final settingsOpened = await openAppSettings();
      return settingsOpened;
    }
    return true;
  }

  static Future<void> initializeBackgroundService() async {
    await FlutterBackgroundService().configure(
      androidConfiguration: const AndroidConfiguration(
        onStart: _onBackgroundStart,
        autoStart: true,
        isForegroundMode: true,
        notificationTitle: 'CaraProjetada',
        notificationContent: 'Servidor VNC ativo',
      ),
      iosConfiguration: const IosConfiguration(),
    );
  }

  static void _onBackgroundStart(ServiceInstance service) {
    // mantém o serviço vivo; o droidVNC-NG roda separado via intent
    service.on('stopService').listen((_) {
      service.stopSelf();
    });
  }
}
