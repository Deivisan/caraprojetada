import 'package:flutter/material.dart';
import '../models/user_prefs.dart';
import '../../services/api_service.dart';
import '../../services/vnc_service.dart';
import '../../services/prefs_service.dart';
import 'onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserPrefs prefs;
  final UserPrefsService prefsService;
  final ApiService api;

  const HomeScreen({
    super.key,
    required this.prefs,
    required this.prefsService,
    required this.api,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  String? _selectedMode;
  List<ConnectionInfo> _boxes = [];
  bool _loading = false;
  String? _error;
  bool _vncRunning = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _selectedMode = widget.prefs.selectedMode;
    if (_selectedMode != null) _goToHome();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) => setState(() => _currentPage = page);

  void _onModeSelected(String mode) async {
    final prefs = widget.prefs.copyWith(selectedMode: mode, onboarded: true);
    await widget.prefsService.save(prefs);
    setState(() => _selectedMode = mode);
    await _loadDevices();
    _goToHome();
  }

  void _goToHome() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadDevices() async {
    setState(() => _loading = true, _error = null);
    try {
      final boxes = await widget.api.getDevices();
      setState(() => _boxes = boxes);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _connect(ConnectionInfo box) async {
    setState(() => _loading = true, _error = null);
    try {
      await VncService.requestPermissions();
      await VncService.initializeBackgroundService();
      await VncService.startVncServer(password: 'caraprojetada', port: '5900');
      await widget.api.connectMobile(
        deviceIp: '172.17.7.99',
        pin: 'caraprojetada',
        orientation: 'retrato',
      );
      setState(() => _vncRunning = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CaraProjetada'), elevation: 2),
      body: _selectedMode == null
          ? OnboardingScreen(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              onModeSelected: _onModeSelected,
            )
          : _buildHome(),
    );
  }

  Widget _buildHome() {
    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_vncRunning) _buildVncActive(),
          if (_error != null) _buildError(),
          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Projetores disponiveis',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._boxes.map((b) => _buildBoxCard(b)),
        ],
      ),
    );
  }

  Widget _buildVncActive() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'VNC ativo — transmitindo para o projetor',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              await VncService().stopVncServer();
              setState(() => _vncRunning = false);
            },
            child: const Text('Parar'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!)),
          IconButton(
            onPressed: () => setState(() => _error = null),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxCard(ConnectionInfo box) {
    final isAvailable = box.available;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAvailable ? Colors.green : Colors.grey,
          child: Icon(isAvailable ? Icons.tv : Icons.tv_off, color: Colors.white),
        ),
        title: Text(box.name),
        subtitle: Text('${box.ip}:${box.port} · ${box.resolution}'),
        trailing: isAvailable
            ? ElevatedButton(
                onPressed: _loading ? null : () => _connect(box),
                child: Text(_loading ? '...' : 'Transmitir'),
              )
            : const Text('Ocupado', style: TextStyle(color: Colors.red)),
      ),
    );
  }
}
