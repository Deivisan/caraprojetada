import 'package:flutter/material.dart';
import 'package:caraprojetada/models/user_prefs.dart';
import 'package:caraprojetada/services/api_service.dart';
import 'package:caraprojetada/services/prefs_service.dart';
import 'package:caraprojetada/screens/home/home_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsScreen extends StatelessWidget {
  final UserPrefs prefs;
  final UserPrefsService prefsService;
  final ApiService api;

  const SettingsScreen({
    super.key,
    required this.prefs,
    required this.prefsService,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('configurações'),
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: Theme.of(context).colorScheme.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1e1b4b), Color(0xFF312e81)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1e1b4b).withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.settings_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'configurações',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'cara projetada v1.0.0',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 20, duration: 400.ms),

          const SizedBox(height: 24),

          // seção: configurações
          _buildSectionTitle('geral'),
          const SizedBox(height: 10),

          _buildSettingCard(
            icon: Icons.refresh_rounded,
            iconBgColor: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFF97316),
            title: 'refazer onboarding',
            subtitle: 'selecionar modo de uso novamente',
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () async {
              await prefsService.clear();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => HomeScreen(
                      prefs: const UserPrefs(),
                      prefsService: prefsService,
                      api: ApiService(),
                    ),
                  ),
                  (route) => false,
                );
              }
            },
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideX(
              begin: 20, duration: 400.ms, delay: 100.ms),

          const SizedBox(height: 24),

          // seção: sobre
          _buildSectionTitle('informações'),
          const SizedBox(height: 10),

          _buildSettingCard(
            icon: Icons.info_outline_rounded,
            iconBgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF3B82F6),
            title: 'versão',
            subtitle: '1.0.0',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4f46e5), Color(0xFF7c5cff)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'estável',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideX(
              begin: 20, duration: 400.ms, delay: 200.ms),

          const SizedBox(height: 12),

          _buildSettingCard(
            icon: Icons.code_rounded,
            iconBgColor: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF7C3AED),
            title: 'stack',
            subtitle: 'flutter + droidVNC-NG',
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideX(
              begin: 20, duration: 400.ms, delay: 300.ms),

          const SizedBox(height: 24),

          // seção: rede
          if (api.isConfigured) ...[
            _buildSectionTitle('rede'),
            const SizedBox(height: 10),
            _buildSettingCard(
              icon: Icons.dns_outlined,
              iconBgColor: const Color(0xFFECFDF5),
              iconColor: const Color(0xFF059669),
              title: 'box conectada',
              subtitle: api.host,
              trailing: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1e1b4b),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}
