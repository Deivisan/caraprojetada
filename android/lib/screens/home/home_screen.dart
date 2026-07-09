import 'package:flutter/material.dart';
import 'package:caraprojetada/models/user_prefs.dart';
import 'package:caraprojetada/services/api_service.dart';
import 'package:caraprojetada/services/vnc_service.dart';
import 'package:caraprojetada/services/prefs_service.dart';
import 'package:caraprojetada/screens/onboarding/onboarding_screen.dart';
import 'package:caraprojetada/screens/settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserPrefs prefs;
  final UserPrefsService prefsService;
  final ApiService api;
  final String? userFullname;

  const HomeScreen({
    super.key,
    required this.prefs,
    required this.prefsService,
    required this.api,
    this.userFullname,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  String? _selectedMode;
  List<dynamic> _boxes = [];
  bool _loading = false;
  bool _discovering = false;
  String? _hostInput;
  String? _error;
  bool _vncRunning = false;
  String? _connectingTo;
  final TextEditingController _hostController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _selectedMode = widget.prefs.selectedMode;
    if (_selectedMode != null) _goToBoxList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hostController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) => setState(() => _currentPage = page);

  void _onModeSelected(String mode) async {
    final prefs = widget.prefs.copyWith(selectedMode: mode, onboarded: true);
    await widget.prefsService.save(prefs);
    setState(() => _selectedMode = mode);
    await Future.delayed(const Duration(milliseconds: 300));
    _goToBoxList();
  }

  void _goToBoxList() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _loadDevices() async {
    if (!widget.api.isConfigured) {
      setState(() => _error = 'Configure o IP da box primeiro');
      return;
    }
    setState(() => _loading = true, _error = null);
    try {
      final boxes = await widget.api.getDevices();
      setState(() => _boxes = boxes);
    } catch (e) {
      setState(() => _error = 'Erro: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _discoverAndConnect() async {
    setState(() => _discovering = true, _error = null);
    try {
      final found = await widget.api.discoverBoxes();
      if (found.isEmpty) {
        setState(() => _error = 'Nenhuma box encontrada. Insira o IP manualmente.');
        return;
      }
      widget.api = ApiService(host: found.first, port: ApiService.defaultPort);
      await _loadDevices();
    } catch (e) {
      setState(() => _error = 'Descoberta falhou: ${e.toString()}');
    } finally {
      setState(() => _discovering = false);
    }
  }

  Future<void> _connectBox(dynamic box) async {
    setState(() => _loading = true, _error = null, _connectingTo = box.name);
    try {
      // solicita permissões
      final permOk = await VncService.requestPermissions();
      if (!permOk && mounted) {
        setState(() => _error = 'Permissoes negadas. Habilite nas configurações.');
        return;
      }

      // inicializa serviço background
      await VncService.initializeBackgroundService();

      // pega IP local do celular para registrar
      final localIp = await getLocalIpAddress();

      // registra dispositivo na box
      await widget.api.registerDevice(
        deviceIp: localIp,
        deviceName: 'Android ${_selectedMode ?? "usuario"}',
        orientation: 'retrato',
      );

      // inicia VNC nativo
      await VncService.startVncServer(
        password: 'caraprojetada',
        port: '5900',
      );

      // conecta via API da box
      await widget.api.connectMobile(
        deviceIp: localIp,
        pin: 'caraprojetada',
        orientation: 'retrato',
      );

      setState(() => _vncRunning = true, _connectingTo = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conectado a ${box.name ?? "box"}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString(), _connectingTo = null);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnboarded = widget.prefs.onboarded;
    final showOnboarding = _selectedMode == null && !isOnboarded;

    return Scaffold(
      body: showOnboarding
          ? OnboardingScreen(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              onModeSelected: _onModeSelected,
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CaraProjetada'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  prefs: widget.prefs,
                  prefsService: widget.prefsService,
                  api: widget.api,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // banner de status
            _buildStatusBanner(),
            const SizedBox(height: 24),
            // seção de descoberta
            _buildDiscoverSection(),
            const SizedBox(height: 20),
            // lista de boxes
            _buildBoxList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_vncRunning) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade600],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cast_connected, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Transmitindo para o projetor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await VncService().stopVncServer();
                setState(() => _vncRunning = false);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
              ),
              child: const Text('Parar'),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade900, fontSize: 13),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _error = null),
              icon: Icon(Icons.close, color: Colors.red.shade700, size: 18),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Conecte-se a mesma rede Wi-Fi do projetor para transmitir.',
              style: TextStyle(color: Colors.blue.shade900, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.explore, color: Colors.blue.shade700, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Buscar projetor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hostController,
                    decoration: InputDecoration(
                      hintText: 'IP da box (ex: 192.168.1.100)',
                      prefixIcon: const Icon(Icons.dns, size: 20),
                      suffixIcon: _hostController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _hostController.clear();
                                widget.api = ApiService(host: '', port: ApiService.defaultPort);
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) {
                      final parts = v.trim().split(':');
                      final h = parts.first.trim();
                      final p = parts.length > 1 ? int.tryParse(parts[1]) : null;
                      widget.api = ApiService(host: h, port: p ?? ApiService.defaultPort);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _discovering ? null : _loadDevices,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search, size: 18),
                  label: Text(_discovering ? 'Buscando...' : 'Conectar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _discovering ? null : _discoverAndConnect,
                icon: _discovering
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find, size: 18),
                label: Text(
                  _discovering ? 'Escaneando rede...' : 'Auto-detectar na rede',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoxList() {
    if (_loading && _boxes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_boxes.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.tv_off, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Nenhum projetor encontrado',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt, color: Colors.amber.shade700, size: 20),
            const SizedBox(width: 6),
            Text(
              'Projetores disponiveis (${_boxes.length})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._boxes.map((b) => _buildBoxCard(b)),
      ],
    );
  }

  Widget _buildBoxCard(dynamic box) {
    final name = box.name ?? 'Projetor';
    final ip = box.ip ?? '--';
    final available = box.available ?? false;
    final resolution = box.resolution ?? '--';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: available ? Colors.green.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            available ? Icons.cast : Icons.cast_connected,
            color: available ? Colors.green.shade700 : Colors.grey,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(ip, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(resolution, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              ),
            ],
          ),
        ),
        trailing: available
            ? FilledButton(
                onPressed: _loading ? null : () => _connectBox(box),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Transmitir'),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Ocupado',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
      ),
    );
  }
}
