import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ─────────────────────────────────────────────────────────────
  late AnimationController _mainCtrl;   // 4700 ms — drives all phases
  late AnimationController _haloCtrl;   // 3600 ms — repeating glow pulse

  // ── Derived animations ───────────────────────────────────────────────────────
  // Phase 1 (0–2400 ms): particles converge onto heart curve
  late Animation<double> _flightAnim;
  // Phase 2 (2400–3100 ms): particles collapse inward and fade
  late Animation<double> _collapseAnim;
  // Phase 3a (3100–3700 ms): logo springs in
  late Animation<double> _logoScaleAnim;
  late Animation<double> _logoFadeAnim;
  // Phase 3b (3700–4600 ms): wordmark slides in
  late Animation<double> _wordmarkAnim;
  // Phase 3c (4000–4700 ms): tagline fades in
  late Animation<double> _taglineAnim;
  // Phase 3d (4200–4700 ms): footer fades in
  late Animation<double> _footerAnim;

  // ── Particle cache ────────────────────────────────────────────────────────────
  List<_ParticleData>? _particles;
  Size? _lastSize;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4700),
    );
    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    // Timing fractions: t / 4700
    // 2400ms = 0.511   3100ms = 0.660   3700ms = 0.787
    // 4000ms = 0.851   4200ms = 0.894   4600ms = 0.979
    _flightAnim = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.0, 0.511, curve: Curves.easeInOut),
    );
    _collapseAnim = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.511, 0.660, curve: Curves.easeIn),
    );
    _logoScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.660, 0.787, curve: Curves.easeOutBack),
      ),
    );
    _logoFadeAnim = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.660, 0.787, curve: Curves.easeOut),
    );
    _wordmarkAnim = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.787, 0.979, curve: Curves.easeOutCubic),
    );
    _taglineAnim = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.851, 1.0, curve: Curves.easeOut),
    );
    _footerAnim = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.894, 1.0, curve: Curves.easeOut),
    );

    _mainCtrl.forward();

    // Start halo pulse at 3300 ms
    Future.delayed(const Duration(milliseconds: 3300), () {
      if (mounted) _haloCtrl.repeat();
    });

    // Auto-advance at end of animation
    Future.delayed(const Duration(milliseconds: 4750), () {
      if (mounted) _goToLogin();
    });
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _haloCtrl.dispose();
    super.dispose();
  }

  void _goToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ── Particle generation ───────────────────────────────────────────────────────

  List<_ParticleData> _buildParticles(Size size) {
    final rng = math.Random(42); // fixed seed → stable layout
    final particles = <_ParticleData>[];
    final cx = size.width * 0.5;
    final cy = size.height * 0.40;
    final sc = size.width * 0.022; // heart-curve scale

    // Heart parametric: x=16sin³t, y=-(13cos t - 5cos2t - 2cos3t - cos4t)
    Offset heartPt(double t) {
      final s = math.sin(t);
      final x = 16.0 * s * s * s;
      final y = -(13.0 * math.cos(t) -
          5.0 * math.cos(2.0 * t) -
          2.0 * math.cos(3.0 * t) -
          math.cos(4.0 * t));
      return Offset(cx + x * sc, cy + y * sc);
    }

    // Random off-screen start position
    Offset offScreen() {
      final a = rng.nextDouble() * math.pi * 2;
      final d = math.max(size.width, size.height) *
          (0.6 + rng.nextDouble() * 0.5);
      return Offset(cx + d * math.cos(a), cy + d * math.sin(a));
    }

    // 120 outline particles along perimeter
    for (int i = 0; i < 120; i++) {
      final t = (i / 120.0) * math.pi * 2 +
          (rng.nextDouble() - 0.5) * 0.12;
      particles.add(_ParticleData(
        start: offScreen(),
        heart: heartPt(t),
        isFill: false,
        radius: 1.6 + rng.nextDouble() * 1.2,
      ));
    }

    // 50 fill particles scattered inside heart
    for (int i = 0; i < 50; i++) {
      final t = rng.nextDouble() * math.pi * 2;
      final f = 0.15 + rng.nextDouble() * 0.65;
      final s = math.sin(t);
      final x = 16.0 * s * s * s * f;
      final y = -(13.0 * math.cos(t) -
              5.0 * math.cos(2.0 * t) -
              2.0 * math.cos(3.0 * t) -
              math.cos(4.0 * t)) *
          f;
      particles.add(_ParticleData(
        start: offScreen(),
        heart: Offset(cx + x * sc, cy + y * sc),
        isFill: true,
        radius: 1.8 + rng.nextDouble() * 2.0,
      ));
    }

    return particles;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goToLogin,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size =
                Size(constraints.maxWidth, constraints.maxHeight);

            // Generate particles once per unique screen size
            if (_particles == null ||
                _lastSize?.width != size.width ||
                _lastSize?.height != size.height) {
              _particles = _buildParticles(size);
              _lastSize = size;
            }

            final cx = size.width * 0.5;
            final cy = size.height * 0.40;

            return Stack(
              children: [
                // ── Background gradient ──────────────────────────────────
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFF8FAFD),
                          Color(0xFFE8EFF8),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Dot grid ─────────────────────────────────────────────
                Positioned.fill(
                  child: CustomPaint(
                    painter: const _DotGridPainter(),
                  ),
                ),

                // ── Halo glow (starts after logo appears) ────────────────
                AnimatedBuilder(
                  animation:
                      Listenable.merge([_mainCtrl, _haloCtrl]),
                  builder: (_, _) {
                    if (_mainCtrl.value < 0.702) {
                      return const SizedBox.shrink();
                    }
                    const r = 220.0;
                    final pulse = 0.10 +
                        0.08 * (1.0 - _haloCtrl.value);
                    return Positioned(
                      left: cx - r,
                      top: cy - r,
                      child: SizedBox(
                        width: r * 2,
                        height: r * 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                kPrimary.withValues(alpha: pulse),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // ── Particle layer ───────────────────────────────────────
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _mainCtrl,
                    builder: (_, _) => CustomPaint(
                      size: size,
                      painter: _ParticlePainter(
                        particles: _particles!,
                        flightProgress: _flightAnim.value,
                        collapseProgress: _collapseAnim.value,
                        center: Offset(cx, cy),
                      ),
                    ),
                  ),
                ),

                // ── Logo (springs in at phase 3) ─────────────────────────
                AnimatedBuilder(
                  animation: _logoScaleAnim,
                  builder: (_, _) {
                    final fade = _logoFadeAnim.value;
                    if (fade <= 0) return const SizedBox.shrink();
                    final scale = _logoScaleAnim.value;
                    return Positioned(
                      left: cx - 110,
                      top: cy - 110,
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: Opacity(
                          opacity: fade.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: scale, // easeOutBack overshoots slightly
                            child: const BrandLogo(
                                size: 220, glassy: true),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // ── Wordmark + tagline + footer ───────────────────────────
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _wordmarkAnim,
                    _taglineAnim,
                    _footerAnim,
                  ]),
                  builder: (_, _) {
                    final wt = _wordmarkAnim.value;
                    final tt = _taglineAnim.value;
                    final ft = _footerAnim.value;
                    if (wt <= 0 && tt <= 0 && ft <= 0) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: size.height * 0.07,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Wordmark — slide up + fade
                          if (wt > 0)
                            Transform.translate(
                              offset: Offset(0, (1 - wt) * 20),
                              child: Opacity(
                                opacity: wt.clamp(0.0, 1.0),
                                child: const Text(
                                  'NurseAssist',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: kInk1,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                              ),
                            ),
                          // Tagline — fade
                          if (tt > 0) ...[
                            const SizedBox(height: 8),
                            Opacity(
                              opacity: tt.clamp(0.0, 1.0),
                              child: const Text(
                                'DETECT WITH PRECISION',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.6,
                                  color: kPrimary,
                                ),
                              ),
                            ),
                          ],
                          // Footer — fade
                          if (ft > 0) ...[
                            const SizedBox(height: 28),
                            Opacity(
                              opacity: ft.clamp(0.0, 1.0),
                              child: const Text(
                                'POWERED BY CLINICAL INTELLIGENCE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.8,
                                  color: kMuted3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _ParticleData {
  final Offset start;
  final Offset heart;
  final bool isFill;
  final double radius;

  const _ParticleData({
    required this.start,
    required this.heart,
    required this.isFill,
    required this.radius,
  });
}

// ── Particle painter ──────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final List<_ParticleData> particles;
  final double flightProgress;   // 0→1 during phase 1
  final double collapseProgress; // 0→1 during phase 2
  final Offset center;

  const _ParticlePainter({
    required this.particles,
    required this.flightProgress,
    required this.collapseProgress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final fillPaint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      Offset pos;
      double alpha;

      if (collapseProgress > 0) {
        // Phase 2: collapse toward center
        pos = Offset.lerp(p.heart, center, collapseProgress)!;
        alpha = (1.0 - collapseProgress).clamp(0.0, 1.0);
      } else {
        // Phase 1: fly from off-screen to heart position
        pos = Offset.lerp(p.start, p.heart, flightProgress)!;
        alpha = flightProgress.clamp(0.0, 1.0);
      }

      if (alpha <= 0.02) continue;

      if (p.isFill) {
        fillPaint.color = kPrimary.withValues(alpha: 0.55 * alpha);
        canvas.drawCircle(pos, p.radius, fillPaint);
      } else {
        outlinePaint.color = kPrimary.withValues(alpha: 0.80 * alpha);
        canvas.drawCircle(pos, p.radius, outlinePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.flightProgress != flightProgress ||
      old.collapseProgress != collapseProgress;
}

// ── Dot grid painter ──────────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 32.0;
    final paint = Paint()
      ..color = const Color(0xFFC8D2E2).withValues(alpha: 0.40);
    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
