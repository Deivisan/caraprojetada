import 'package:flutter/material.dart';
import 'package:caraprojetada/models/user_prefs.dart';
import 'package:caraprojetada/services/api_service.dart';
import 'package:caraprojetada/services/prefs_service.dart';
import 'package:caraprojetada/screens/home/home_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SplashScreen extends StatefulWidget {
  final UserPrefs prefs;
  final UserPrefsService prefsService;
  final ApiService api;

  const SplashScreen({
    super.key,
    required this.prefs,
    required this.prefsService,
    required this.api,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => HomeScreen(
              prefs: widget.prefs,
              prefsService: widget.prefsService,
              api: widget.api,
            ),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
              Color(0xFF7c5cff),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // projector icon animado
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: CustomPaint(
                  painter: _ProjectorPainter(),
                  size: const Size(80, 80),
                ),
              )
                  .animate()
                  .scale(duration: 800.ms, curve: Curves.elasticOut)
                  .then()
                  .shimmer(duration: 1500.ms, color: Colors.white.withValues(alpha: 0.3)),

              const SizedBox(height: 32),

              // título
              Text(
                'CaraProjetada',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1.1,
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 300.ms)
                  .slideY(begin: 20, duration: 600.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: 10),

              Text(
                'transmita sua tela para o projetor',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 500.ms)
                  .slideY(begin: 15, duration: 600.ms, curve: Curves.easeOutCubic),

              const Spacer(),

              // beam animado (pulsing)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 120 + _pulseController.value * 30,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFFfbbf24).withValues(
                              alpha: 0.3 + _pulseController.value * 0.4),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                },
              ).animate().fadeIn(duration: 800.ms, delay: 800.ms),

              const SizedBox(height: 40),

              Text(
                'v $v',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 1200.ms),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

const v = '1.0.0';

class _ProjectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.9);

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // beam
    final beamPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFfbbf24).withValues(alpha: 0.3);
    final beamPath = Path()
      ..moveTo(centerX, centerY - 8)
      ..lineTo(centerX - 28, centerY + 30)
      ..lineTo(centerX + 28, centerY + 30)
      ..close();
    canvas.drawPath(beamPath, beamPaint);

    // body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY - 10),
        width: 44,
        height: 28,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, paint);

    // lens
    paint.color = Colors.white.withValues(alpha: 0.5);
    canvas.drawCircle(Offset(centerX, centerY - 10), 10, paint);

    paint.color = const Color(0xFFfbbf24).withValues(alpha: 0.6);
    canvas.drawCircle(Offset(centerX, centerY - 10), 5, paint);

    paint.color = Colors.white;
    canvas.drawCircle(Offset(centerX - 2, centerY - 12), 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
