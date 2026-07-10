import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';

/// tela fullscreen de projecao de pdf no celular.
/// funciona como um controle remoto inteligente:
/// - tap na esquerda = pagina anterior
/// - tap na direita = proxima pagina
/// - swipe pra cima = mostra menu de controle (voltar, parar, pular p/ pagina)
/// - exibe info da pagina em destaque
class PdfProjectionScreen extends StatefulWidget {
  final String boxIp;
  final int totalPages;
  final String? localPdfPath; // caminho local do pdf para abrir no celular
  final VoidCallback onStop;
  final VoidCallback onBack;

  const PdfProjectionScreen({
    super.key,
    required this.boxIp,
    required this.totalPages,
    this.localPdfPath,
    required this.onStop,
    required this.onBack,
  });

  @override
  State<PdfProjectionScreen> createState() => _PdfProjectionScreenState();
}

class _PdfProjectionScreenState extends State<PdfProjectionScreen> {
  int _currentPage = 1;
  bool _showMenu = false;
  Timer? _menuTimer;
  bool _loadingPrev = false;
  bool _loadingNext = false;

  @override
  void initState() {
    super.initState();
    // landscape e sem barra de sistema
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _menuTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _navigate(String dir) async {
    if (dir == 'prev' && _currentPage <= 1) return;
    if (dir == 'next' && _currentPage >= widget.totalPages) return;

    setState(() {
      if (dir == 'prev') _loadingPrev = true;
      if (dir == 'next') _loadingNext = true;
    });

    try {
      final endpoint = dir == 'next'
          ? '/api/v1/project-next'
          : '/api/v1/project-prev';
      final uri = Uri.parse('http://${widget.boxIp}$endpoint');
      await http.post(uri);
      if (mounted) {
        setState(() {
          if (dir == 'next') _currentPage++;
          if (dir == 'prev') _currentPage--;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _loadingPrev = false;
        _loadingNext = false;
      });
    }

    // feedback haptico
    HapticFeedback.lightImpact();
  }

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
      if (_showMenu) {
        _menuTimer?.cancel();
        _menuTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showMenu = false);
        });
      } else {
        _menuTimer?.cancel();
      }
    });
  }

  Future<void> _stopAndBack() async {
    try {
      await http.post(
          Uri.parse('http://${widget.boxIp}/api/v1/project-stop'));
    } catch (_) {}
    widget.onStop();
    widget.onBack();
  }

  Future<void> _openOnPhone() async {
    if (widget.localPdfPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('pdf nao encontrado no dispositivo')),
        );
      }
      return;
    }
    final result = await OpenFilex.open(widget.localPdfPath!);
    if (mounted && result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('erro ao abrir pdf: ${result.message}')),
      );
    }
  }

  void _goToPage() {
    // mostra dialog para pular pagina
    final controller = TextEditingController(text: _currentPage.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text('ir para página',
            style: GoogleFonts.poppins(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 24),
          decoration: InputDecoration(
            hintText: '1 - ${widget.totalPages}',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancelar',
                style: GoogleFonts.poppins(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= widget.totalPages) {
                // navega ate a pagina desejada
                final diff = page - _currentPage;
                if (diff > 0) {
                  for (int i = 0; i < diff; i++) {
                    await _navigate('next');
                    await Future.delayed(const Duration(milliseconds: 200));
                  }
                } else if (diff < 0) {
                  for (int i = 0; i < -diff; i++) {
                    await _navigate('prev');
                    await Future.delayed(const Duration(milliseconds: 200));
                  }
                }
              }
            },
            child: Text('ir',
                style: GoogleFonts.poppins(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final w = MediaQuery.of(context).size.width;
          final x = details.localPosition.dx;

          if (_showMenu) {
            _toggleMenu(); // qualquer toque fecha menu
            return;
          }

          if (x < w * 0.33) {
            // terco esquerdo = anterior
            _navigate('prev');
          } else if (x > w * 0.66) {
            // terco direito = proximo
            _navigate('next');
          } else {
            // centro = menu
            _toggleMenu();
          }
        },
        child: Stack(
          children: [
            // info central da pagina
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // numero da pagina enorme
                  Text(
                    '$_currentPage',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 120,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'de ${widget.totalPages}',
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 22,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // indicadores de toque
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _tapHint('< anterior', Icons.touch_app),
                      const SizedBox(width: 40),
                      _tapHint('menu', Icons.menu),
                      const SizedBox(width: 40),
                      _tapHint('próximo >', Icons.touch_app),
                    ],
                  ),
                ],
              ),
            ),

            // setas laterais (indicadores visuais)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _currentPage > 1 ? 0.4 : 0.1,
                  duration: const Duration(milliseconds: 200),
                  child: _loadingPrev
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              color: Colors.white38, strokeWidth: 2))
                      : const Icon(Icons.chevron_left,
                          color: Colors.white38, size: 48),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _currentPage < widget.totalPages ? 0.4 : 0.1,
                  duration: const Duration(milliseconds: 200),
                  child: _loadingNext
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              color: Colors.white38, strokeWidth: 2))
                      : const Icon(Icons.chevron_right,
                          color: Colors.white38, size: 48),
                ),
              ),
            ),

            // barra de progresso inferior
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: _currentPage / widget.totalPages,
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                minHeight: 3,
              ),
            ),

            // menu de controle (aparece ao tocar no centro)
            if (_showMenu)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        // voltar
                        _menuButton(
                          Icons.arrow_back,
                          'voltar',
                          onTap: () {
                            _menuTimer?.cancel();
                            _stopAndBack();
                          },
                        ),
                        const Spacer(),
                        // info
                        Text(
                          'pg $_currentPage / ${widget.totalPages}',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        // ir para pagina
                        _menuButton(
                          Icons.numbers,
                          'pular',
                          onTap: _goToPage,
                        ),
                        const SizedBox(width: 8),
                        // abrir pdf no celular
                        if (widget.localPdfPath != null)
                          _menuButton(
                            Icons.phone_android,
                            'celular',
                            onTap: _openOnPhone,
                          ),
                        const SizedBox(width: 8),
                        // parar projecao
                        _menuButton(
                          Icons.stop_circle_outlined,
                          'parar',
                          color: Colors.redAccent,
                          onTap: () {
                            _menuTimer?.cancel();
                            _stopAndBack();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tapHint(String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white24, size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white24,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _menuButton(IconData icon, String label,
      {VoidCallback? onTap, Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
