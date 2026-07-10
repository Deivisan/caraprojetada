import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

class ProjectionControlScreen extends StatefulWidget {
  final String boxIp;
  final String boxName;
  final String? userFullname;
  final VoidCallback onStop;

  const ProjectionControlScreen({
    super.key,
    required this.boxIp,
    required this.boxName,
    this.userFullname,
    required this.onStop,
  });

  @override
  State<ProjectionControlScreen> createState() => _ProjectionControlScreenState();
}

class _ProjectionControlScreenState extends State<ProjectionControlScreen> {
  int _selectedTab = 0; // 0=screen, 1=pdf
  bool _uploading = false;
  String? _uploadStatus;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _projectionActive = false;

  Future<void> _pickAndUploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadStatus = 'enviando pdf...';
    });

    try {
      final file = File(result.files.single.path!);
      final uri = Uri.parse('http://${widget.boxIp}/api/v1/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _totalPages = data['pages'] ?? 1;
          _currentPage = 1;
          _uploadStatus = 'pdf carregado (${_totalPages} pg)';
        });
      } else {
        setState(() => _uploadStatus = 'erro no upload');
      }
    } catch (e) {
      setState(() => _uploadStatus = 'erro: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _projectAction(String action) async {
    final endpoint = action == 'start'
        ? '/api/v1/project-start'
        : action == 'next'
            ? '/api/v1/project-next'
            : '/api/v1/project-prev';

    try {
      final uri = Uri.parse('http://${widget.boxIp}$endpoint');
      final resp = await http.post(uri);
      if (mounted && action == 'start' && resp.statusCode == 200) {
        setState(() => _projectionActive = true);
      }
      if (mounted) {
        setState(() {
          if (action == 'next') _currentPage++;
          if (action == 'prev' && _currentPage > 1) _currentPage--;
        });
      }
    } catch (_) {}
  }

  Future<void> _stopProjection() async {
    try {
      await http.post(Uri.parse('http://${widget.boxIp}/api/v1/project-stop'));
      if (mounted) setState(() => _projectionActive = false);
    } catch (_) {}
  }

  Future<void> _stopAll() async {
    await _stopProjection();
    try {
      await http.post(Uri.parse('http://${widget.boxIp}/api/v1/force-disconnect'));
    } catch (_) {}
    widget.onStop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.userFullname != null
              ? '${widget.userFullname} — ${widget.boxName}'
              : 'controle — ${widget.boxName}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F0A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _tabButton('compartilhar tela', 0),
                    _tabButton('enviar pdf', 1),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _selectedTab == 0 ? _buildScreenTab() : _buildPdfTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final active = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: active ? Colors.white : Colors.white60,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreenTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        _infoCard(
          icon: Icons.monitor_heart,
          title: widget.userFullname != null
              ? '${widget.userFullname} — transmitindo'
              : 'projetando tela',
          subtitle: 'sua tela está sendo transmitida para o projetor',
          color: Colors.greenAccent,
        ),
        const SizedBox(height: 24),
        _actionCard(
          icon: Icons.stop_circle_outlined,
          title: 'parar transmissão',
          subtitle: 'encerra o compartilhamento de tela',
          color: Colors.redAccent,
          onTap: _stopAll,
        ),
      ],
    );
  }

  Widget _buildPdfTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        _infoCard(
          icon: Icons.picture_as_pdf,
          title: _uploadStatus ?? 'nenhum pdf carregado',
          subtitle: _uploadStatus != null
              ? 'página $_currentPage de $_totalPages'
              : 'selecione um arquivo pdf para projetar',
          color: Colors.orangeAccent,
        ),
        const SizedBox(height: 24),
        // upload button
        _actionCard(
          icon: Icons.upload_file,
          title: 'enviar pdf',
          subtitle: 'seleciona um arquivo pdf do dispositivo',
          color: Colors.blueAccent,
          loading: _uploading,
          onTap: _pickAndUploadPdf,
        ),
        if (_totalPages > 0) ...[
          const SizedBox(height: 16),

          // botoes de acao: iniciar / parar projecao
          if (!_projectionActive)
            _actionCard(
              icon: Icons.play_circle_outline,
              title: 'iniciar projeção',
              subtitle: 'exibe o pdf no projetor ($_totalPages páginas)',
              color: Colors.greenAccent,
              onTap: () => _projectAction('start'),
            )
          else ...[
            // navigation card (so aparece com projecao ativa)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    'navegação',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _navButton(
                        Icons.skip_previous,
                        'anterior',
                        onTap: () => _projectAction('prev'),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_currentPage / $_totalPages',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _navButton(
                        Icons.skip_next,
                        'próximo',
                        onTap: () => _projectAction('next'),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
            const SizedBox(height: 12),
            _actionCard(
              icon: Icons.stop_circle_outlined,
              title: 'parar projeção',
              subtitle: 'interrompe a exibição do pdf',
              color: Colors.redAccent,
              onTap: _stopProjection,
            ),
          ],
          const SizedBox(height: 12),

          // voltar a espelhar tela (para pdf e volta pra tab screen)
          _actionCard(
            icon: Icons.monitor_heart,
            title: 'voltar a espelhar tela',
            subtitle: 'para o pdf e volta a transmitir a tela do celular',
            color: Colors.blueAccent,
            onTap: () async {
              await _stopProjection();
              if (mounted) setState(() => _selectedTab = 0);
            },
          ),
        ],
        const SizedBox(height: 32),
        // stop all
        _actionCard(
          icon: Icons.power_settings_new,
          title: 'encerrar tudo',
          subtitle: 'para projeção e desconecta',
          color: Colors.redAccent,
          onTap: _stopAll,
        ),
      ],
    );
  }

  Widget _navButton(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3);
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool loading = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: loading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: color,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38, size: 28),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3);
  }
}
