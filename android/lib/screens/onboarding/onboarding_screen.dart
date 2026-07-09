import 'package:flutter/material.dart';

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
      body: SafeArea(
        child: Column(
          children: [
            // indicador de página
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: active ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
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
    );
  }

  Widget _buildModePage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(Icons.present_to_all_rounded, size: 64, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 36),
          Text(
            'Modo de Apresentacao',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade900,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            'Como voce quer usar o CaraProjetada?',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          ...['Aula', 'Reuniao', 'Apresentacao', 'Demo'].map((opt) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => widget.onModeSelected(opt.toLowerCase()),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.blue.shade200),
                      ),
                    ),
                    child: Text(opt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              )),
        ],
      ),
      ),
    );
  }

  Widget _buildWifiPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(Icons.wifi_rounded, size: 64, color: Colors.purple.shade700),
          ),
          const SizedBox(height: 36),
          Text(
            'Conecte-se à Rede',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            'Conecte este celular na mesma rede Wi-Fi do projetor.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: () => widget.onModeSelected('aula'),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Estou conectado'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildQrPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(Icons.qr_code_scanner_rounded, size: 64, color: Colors.amber.shade700),
          ),
          const SizedBox(height: 36),
          Text(
            'Encontre o Projetor',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            'Escaneie o QR code da tela idle ou digite o IP manualmente.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: () => widget.onModeSelected('aula'),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Escanear QR Code'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
