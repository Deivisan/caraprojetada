import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  final PageController controller;
  final Function(int) onPageChanged;
  final Function(String) onModeSelected;

  const OnboardingScreen({
    super.key,
    required this.controller,
    required this.onPageChanged,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: controller,
      onPageChanged: onPageChanged,
      children: [
        _buildPage(
          context,
          icon: Icons.present_to_all,
          title: 'Modo de Uso',
          subtitle: 'Como voce quer usar?',
          description: 'Aula, reuniao, apresentacao ou demonstracao',
          options: const ['aula', 'reuniao', 'apresentacao', 'demo'],
          onSelect: onModeSelected,
        ),
        _buildPage(
          context,
          icon: Icons.wifi,
          title: 'Rede Wi-Fi',
          subtitle: 'Conecte-se a mesma rede',
          description: 'Ambos dispositivos devem estar na mesma rede Wi-Fi',
          showButton: true,
          buttonText: 'Ja estou conectado',
        ),
        _buildPage(
          context,
          icon: Icons.qr_code_scanner,
          title: 'Escaneie ou Digite',
          subtitle: 'Encontre o projetor',
          description: 'Escaneie o QR code da tela idle do projetor ou digite o IP',
          showButton: true,
          buttonText: 'Escanear QR Code',
        ),
      ],
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? description,
    List<String>? options,
    Function(String)? onSelect,
    bool showButton = false,
    String buttonText = '',
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Theme.of(context).primaryColor),
          const SizedBox(height: 40),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          if (description != null)
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          if (options != null && onSelect != null) ...[
            const SizedBox(height: 32),
            ...options.map(
              (opt) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => onSelect(opt),
                    style: ElevatedButton(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue[800],
                    ).style?.copyWith(
                      padding: const MaterialStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                    child: Text(
                      opt.charAt(0).toUpperCase() + opt.substring(1),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (showButton) ...[
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ).style?.copyWith(
                  padding: const MaterialStatePropertyAll(
                    EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
                child: Text(buttonText, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
