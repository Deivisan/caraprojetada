import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caraprojetada/models/user_prefs.dart';
import 'package:caraprojetada/models/connection_info.dart';
import 'package:caraprojetada/services/api_service.dart';
import 'package:caraprojetada/services/vnc_service.dart';
import 'package:caraprojetada/services/prefs_service.dart';
import 'package:caraprojetada/screens/onboarding/onboarding_screen.dart';
import 'package:caraprojetada/screens/settings/settings_screen.dart';
import 'package:caraprojetada/screens/projection/projection_control_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  String? _selectedMode;
  List<ConnectionInfo> _boxes = [];
  bool _loading = false;
  bool _discovering = false;
  String? _error;
  bool _vncRunning = false;
  ConnectionInfo? _connectedBox;
  late ApiService _api;
  final TextEditingController _hostController = TextEditingController();
  Timer? _statusTimer;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _api = widget.api;
    _selectedMode = widget.prefs.selectedMode;

    // restaura ip salvo
    if (widget.prefs.boxIp != null && widget.prefs.boxIp!.isNotEmpty) {
      _hostController.text = widget.prefs.boxIp!;
      if (!_api.isConfigured) {
        _api = ApiService(
          host: widget.prefs.boxIp!,
          port: widget.prefs.boxPort,
        );
      }
    }

    if (_api.isConfigured) _loadDevices();

    // polling de status (corrigido: active_session)
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_api.isConfigured && mounted) _checkVncStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _hostController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkVncStatus() async {
    try {
      final status = await _api.getStatus();
      final active = status['active_session'] == true;
      if (mounted) {
        setState(() {
          _vncRunning = active;
          if (!active) _connectedBox = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _vncRunning = false;
        _connectedBox = null;
      });
    }
  }

  void _onModeSelected(String mode) async {
    final prefs = widget.prefs.copyWith(selectedMode: mode, onboarded: true);
    await widget.prefsService.save(prefs);
    setState(() => _selectedMode = mode);
  }

  Future<void> _loadDevices() async {
    if (!_api.isConfigured) {
      setState(() => _error = 'digite o ip da box primeiro');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final boxes = await _api.getDevices();
      if (mounted) setState(() => _boxes = boxes);
    } catch (e) {
      if (mounted) setState(() => _error = 'box offline: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _discoverAndConnect() async {
    setState(() {
      _discovering = true;
      _error = null;
    });
    try {
      final found = await _api.discoverBoxes();
      if (found.isEmpty) {
        if (mounted) {
          setState(() => _error = 'nenhuma box encontrada. insira o ip manualmente.');
        }
        return;
      }
      final discoveredIp = found.first;
      _api = ApiService(host: discoveredIp, port: ApiService.defaultPort);
      _hostController.text = discoveredIp;
      // persiste ip descoberto
      final prefs = widget.prefs.copyWith(boxIp: discoveredIp, boxPort: ApiService.defaultPort);
      await widget.prefsService.save(prefs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('box encontrada: $discoveredIp'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      await _loadDevices();
    } catch (e) {
      if (mounted) setState(() => _error = 'descoberta falhou: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  /// pergunta o nome do usuario antes de conectar (se ainda nao foi salvo)
  Future<String?> _ensureUserFullname() async {
    if (widget.prefs.userFullname != null &&
        widget.prefs.userFullname!.trim().isNotEmpty) {
      return widget.prefs.userFullname;
    }
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('quem está transmitindo?',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'seu nome',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('pular', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('confirmar'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final prefs = widget.prefs.copyWith(userFullname: name);
      await widget.prefsService.save(prefs);
    }
    return (name != null && name.isNotEmpty) ? name : null;
  }

  Future<void> _lockOrientationLandscape() {
    return SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _restoreOrientation() {
    return SystemChrome.setPreferredOrientations([]);
  }

  Future<void> _connectBox(ConnectionInfo box) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // pede nome do usuario se ainda nao tem
      final userFullname = await _ensureUserFullname();

      // trava orientacao em landscape e aguarda rotacionar
      await _lockOrientationLandscape();
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('preparando conexão...'),
            backgroundColor: const Color(0xFF4f46e5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      // limpa sessão anterior pendente na box
      await _api.forceDisconnect();

      // para servidor vnc anterior se ainda estiver rodando
      await VncService().stopVncServer();

      final permOk = await VncService.requestPermissions();
      if (!permOk && mounted) {
        setState(() => _error = 'permissoes negadas. habilite nas configs.');
        return;
      }

      await VncService.initializeBackgroundService();

      final localIp = await getLocalIpAddress();

      await _api.registerDevice(
        deviceIp: localIp,
        deviceName: userFullname ?? 'Android ${_selectedMode ?? "usuario"}',
        orientation: 'paisagem',
        userFullname: userFullname,
      );

      await VncService().startVncServer(
        password: 'caraprojetada',
        port: '5900',
      );

      await _api.connectMobile(
        deviceIp: localIp,
        pin: 'caraprojetada',
        orientation: 'paisagem',
        userFullname: userFullname,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('conectado! sua tela está no projetor'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _vncRunning = true;
          _connectedBox = box;
        });
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ProjectionControlScreen(
              boxIp: box.ip,
              boxName: box.name,
              userFullname: userFullname,
              onStop: () {
                _api.forceDisconnect();
                _restoreOrientation();
                setState(() => _vncRunning = false);
              },
            ),
            transitionsBuilder: (_, animation, __, child) =>
                SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      }
    } catch (e) {
      // restaura orientacao em caso de erro
      _restoreOrientation();
      if (mounted) {
        setState(() => _error = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('erro: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnboarded = widget.prefs.onboarded;
    final showOnboarding = _selectedMode == null && !isOnboarded;

    return Scaffold(
      body: showOnboarding
          ? OnboardingScreen(onModeSelected: _onModeSelected)
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4f46e5), Color(0xFF7c5cff)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.present_to_all_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('CaraProjetada'),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: IconButton(
              icon: Icon(Icons.tune_rounded,
                  color: Theme.of(context).colorScheme.primary),
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => SettingsScreen(
                    prefs: widget.prefs,
                    prefsService: widget.prefsService,
                    api: _api,
                  ),
                  transitionsBuilder: (_, animation, __, child) =>
                      SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
          children: [
            // status banner animado
            _buildStatusBanner().animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // seção de descoberta
            _buildDiscoverSection().animate().fadeIn(duration: 500.ms, delay: 100.ms),

            const SizedBox(height: 24),

            // lista de boxes
            _buildBoxList().animate().fadeIn(duration: 600.ms, delay: 200.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_vncRunning) {
      return _buildGlassCard(
        gradientColors: [const Color(0xFF059669), const Color(0xFF047857)],
        child: Row(
          children: [
            _pulsingDot(Colors.greenAccent),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'transmitindo agora',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'sua tela está no projetor',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                if (_connectedBox != null) {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => ProjectionControlScreen(
                        boxIp: _connectedBox!.ip,
                        boxName: _connectedBox!.name,
                        onStop: () {
                          _api.forceDisconnect();
                          setState(() => _vncRunning = false);
                        },
                      ),
                      transitionsBuilder: (_, animation, __, child) =>
                          SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(1, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                      transitionDuration: const Duration(milliseconds: 350),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('controles',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.red.shade600, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade900, fontSize: 13),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _error = null),
              icon: Icon(Icons.close_rounded,
                  color: Colors.red.shade600, size: 20),
            ),
          ],
        ),
      );
    }

    return _buildGlassCard(
      gradientColors: [
        const Color(0xFF1e1b4b).withValues(alpha: 0.85),
        const Color(0xFF312e81).withValues(alpha: 0.85),
      ],
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.wifi_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'conecte-se à mesma rede wi-fi do projetor para transmitir.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required List<Color> gradientColors,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _pulsingDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4f46e5), Color(0xFF7c5cff)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.explore_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'buscar projetor',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1e1b4b),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hostController,
                  decoration: InputDecoration(
                    hintText: 'ip da box (ex: 192.168.1.100)',
                    prefixIcon: const Icon(Icons.dns_outlined, size: 20),
                    suffixIcon: _hostController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _hostController.clear();
                              setState(() {
                                _api = ApiService(
                                    host: '', port: ApiService.defaultPort);
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) async {
                    final parts = v.trim().split(':');
                    final h = parts.first.trim();
                    final p = parts.length > 1 ? int.tryParse(parts[1]) : null;
                    setState(() {
                      _api = ApiService(
                          host: h, port: p ?? ApiService.defaultPort);
                    });
                    // persiste ip automaticamente
                    if (h.isNotEmpty) {
                      final prefs = widget.prefs.copyWith(
                        boxIp: h,
                        boxPort: p ?? ApiService.defaultPort,
                      );
                      await widget.prefsService.save(prefs);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _discovering ? null : _loadDevices,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  backgroundColor: const Color(0xFF1e1b4b),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                  : const Icon(Icons.wifi_find_rounded, size: 18),
              label: Text(
                _discovering ? 'escaneando rede...' : 'auto-detectar na rede',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxList() {
    if (_loading && _boxes.isEmpty) {
      return _buildShimmerLoading();
    }

    if (_boxes.isEmpty && !_loading) {
      return Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.tv_off_rounded,
                size: 40, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 16),
          Text(
            'nenhum projetor encontrado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'tente auto-detectar ou digite o ip manualmente',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'projetores disponíveis (${_boxes.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1e1b4b),
                ),
              ),
            ],
          ),
        ),
        ..._boxes.asMap().entries.map((entry) {
          final index = entry.key;
          final box = entry.value;
          return _buildBoxCard(box).animate().fadeIn(
                duration: 300.ms,
                delay: (index * 80).ms,
              );
        }),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      )),
    );
  }

  Widget _buildBoxCard(ConnectionInfo box) {
    final name = box.name;
    final ip = box.ip;
    final available = box.available;
    final resolution = box.resolution;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: available
              ? const Color(0xFFA7F3D0).withValues(alpha: 0.5)
              : Colors.grey.shade200,
          width: available ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: available && !_loading ? () => _connectBox(box) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: available
                        ? const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                          )
                        : LinearGradient(
                            colors: [Colors.grey.shade300, Colors.grey.shade400],
                          ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    available ? Icons.cast_rounded : Icons.cast_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF1e1b4b),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            ip,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              resolution,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (available)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1e1b4b), Color(0xFF312e81)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'transmitir',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'ocupado',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
