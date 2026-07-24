import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OnboardingScreen extends StatefulWidget {
  final Function(String) onModeSelected;

  const OnboardingScreen({
    super.key,
    required this.onModeSelected,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1e1b4b),
              Color(0xFF312e81),
              Color(0xFF4f46e5),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // indicador de página
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final active = i == _page;
                    return GestureDetector(
                      onTap: () => _controller.animateToPage(i,
                          duration: 300.ms, curve: Curves.easeInOut),
                      child: AnimatedContainer(
                        duration: 300.ms,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: active ? 32 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFfbbf24)
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // skip button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => widget.onModeSelected('apresentacao'),
                  child: Text(
                    'pular',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (p) => setState(() => _page = p),
                  children: [
                    _buildModePage(),
                    _buildWifiPage(),
                    _buildQrPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIcon(IconData icon, {Color? color}) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Icon(icon, size: 52, color: color ?? const Color(0xFFfbbf24)),
    );
  }

  Widget _buildPageTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildPageSubtitle(String subtitle) {
    return Text(
      subtitle,
      style: TextStyle(
        fontSize: 15,
        color: Colors.white.withValues(alpha: 0.7),
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildModePage() {
    final modes = [
      {'label': 'aula', 'icon': Icons.school_rounded, 'desc': 'para ensinar'},
      {'label': 'reuniao', 'icon': Icons.groups_rounded, 'desc': 'para apresentar'},
      {'label': 'apresentacao', 'icon': Icons.slideshow_rounded, 'desc': 'para palestrar'},
      {'label': 'demo', 'icon': Icons.precision_manufacturing_rounded, 'desc': 'para demonstrar'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          _buildPageIcon(Icons.present_to_all_rounded)
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 28),
          _buildPageTitle('modo de uso')
              .animate()
              .fadeIn(duration: 500.ms, delay: 200.ms),
          const SizedBox(height: 10),
          _buildPageSubtitle('como você quer usar o caraprojetada?')
              .animate()
              .fadeIn(duration: 500.ms, delay: 300.ms),
          const SizedBox(height: 32),
          ...modes.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => widget.onModeSelected(m['label'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(m['icon'] as IconData,
                            color: const Color(0xFFfbbf24), size: 24),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['label'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              m['desc'] as String,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 14),
                      ],
                    ),
                  ).animate().fadeIn(
                      duration: 400.ms,
                      delay: (400 + i * 80).ms,
                    ).slideX(begin: 20, duration: 400.ms,
                        delay: (400 + i * 80).ms, curve: Curves.easeOutCubic),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWifiPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          _buildPageIcon(Icons.wifi_rounded, color: Colors.cyanAccent)
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 28),
          _buildPageTitle('conecte-se à rede')
              .animate()
              .fadeIn(duration: 500.ms, delay: 200.ms),
          const SizedBox(height: 10),
          _buildPageSubtitle(
                  'conecte este celular na mesma rede wi-fi do projetor para começar.')
              .animate()
              .fadeIn(duration: 500.ms, delay: 300.ms),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.wifi_find_rounded,
                    color: Colors.cyanAccent.withValues(alpha: 0.8), size: 40),
                const SizedBox(height: 12),
                Text(
                  'dica: o app escaneia a rede automaticamente\n e descobre o projetor pra você.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
          const SizedBox(height: 36),
          FilledButton.icon(
            onPressed: () => widget.onModeSelected('apresentacao'),
            icon: const Icon(Icons.check_rounded),
            label: const Text('estou conectado'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFfbbf24),
              foregroundColor: const Color(0xFF1e1b4b),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildQrPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          _buildPageIcon(Icons.qr_code_scanner_rounded,
                  color: const Color(0xFFfbbf24))
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 28),
          _buildPageTitle('encontre o projetor')
              .animate()
              .fadeIn(duration: 500.ms, delay: 200.ms),
          const SizedBox(height: 10),
          _buildPageSubtitle(
                  'escaneie o qr code na tela inativa do projetor ou digite o ip manualmente.')
              .animate()
              .fadeIn(duration: 500.ms, delay: 300.ms),
          const SizedBox(height: 36),

          // qr placeholder
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(16),
            child: CustomPaint(
              painter: _QrPlaceholderPainter(),
              size: const Size(128, 128),
            ),
          ).animate().scale(duration: 600.ms, delay: 350.ms, curve: Curves.easeOutCubic),

          const SizedBox(height: 32),

          FilledButton.icon(
            onPressed: () => widget.onModeSelected('apresentacao'),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('escanear qr code'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFfbbf24),
              foregroundColor: const Color(0xFF1e1b4b),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),

          const SizedBox(height: 16),

          TextButton(
            onPressed: () {
              _controller.animateToPage(1,
                  duration: 300.ms, curve: Curves.easeInOut);
            },
            child: Text(
              'ou digite o ip manualmente',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
        ],
      ),
    );
  }
}

class _QrPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1e1b4b)
      ..style = PaintingStyle.fill;

    final s = size.width / 33;

    // desenha um QR code estilizado simplificado
    void drawAt(int x, int y) {
      canvas.drawRect(
        Rect.fromLTWH(x * s, y * s, s * 3, s * 3),
        paint,
      );
    }

    // corners
    drawAt(0, 0);
    drawAt(0, 8);
    drawAt(8, 0);
    drawAt(24, 0);
    drawAt(24, 8);
    drawAt(0, 24);
    drawAt(8, 24);

    paint..color = const Color(0xFF1e1b4b).withValues(alpha: 0.6);
    // dots
    for (final p in [
      [12, 3], [16, 3], [20, 5], [14, 8], [18, 10],
      [12, 12], [16, 12], [20, 12], [14, 16], [22, 16],
      [28, 12], [28, 18], [24, 20], [20, 24], [26, 24],
      [12, 20], [12, 28], [18, 28], [24, 28], [28, 28],
      [14, 20], [15, 22], [20, 14], [26, 14], [28, 24],
      [3, 12], [5, 16], [3, 20],
    ]) {
      canvas.drawRect(
        Rect.fromLTWH(p[0] * s, p[1] * s, s * 2, s * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
