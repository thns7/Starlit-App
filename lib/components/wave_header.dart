import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:starlitfilms/theme/tokens.dart';

/// Faixa violeta com borda inferior em onda, desenhada em código: se adapta a
/// qualquer largura/altura (nunca corta) e ondula devagar. Substitui os PNGs
/// de onda que eram recortados com BoxFit.cover.
class WaveHeader extends StatefulWidget {
  final double waveHeight;
  final bool secondLayer;
  final Widget? child;

  const WaveHeader({
    super.key,
    this.waveHeight = 70,
    this.secondLayer = false,
    this.child,
  });

  static const color = Color(0xFF5A36B0);

  @override
  State<WaveHeader> createState() => _WaveHeaderState();
}

class _WaveHeaderState extends State<WaveHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 9));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _WavePainter(_c, widget.waveHeight, widget.secondLayer),
        child: widget.child,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Animation<double> t;
  final double waveHeight;
  final bool secondLayer;

  _WavePainter(this.t, this.waveHeight, this.secondLayer) : super(repaint: t);

  Path _wave(Size size, double phase, double amp, double baseline) {
    final w = size.width;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, baseline + amp * math.sin(phase + 2 * math.pi));
    const steps = 48;
    for (var i = steps; i >= 0; i--) {
      final x = w * i / steps;
      // Uma onda longa e suave (1,2 ciclos na largura) com leve harmônico.
      final k = 2 * math.pi * 1.2 * i / steps;
      final y = baseline + amp * math.sin(k + phase) + amp * 0.25 * math.sin(2 * k - phase);
      path.lineTo(x, y);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t.value * 2 * math.pi;
    final amp = waveHeight / 2;
    final base = size.height - amp * 1.3;

    if (secondLayer) {
      final back = _wave(size, phase + 1.4, amp * 0.9, base + amp * 0.35);
      canvas.drawPath(back, Paint()..color = SC.starSoft.withValues(alpha: 0.35));
    }
    final front = _wave(size, phase, amp, base);
    canvas.drawShadow(front, const Color(0xFF05020D), 10, false);
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4F2FA3), WaveHeader.color],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.waveHeight != waveHeight || old.secondLayer != secondLayer;
}

/// Flutuação lenta e contínua (logo da tela de entrada).
class FloatingBob extends StatefulWidget {
  final Widget child;
  final double distance;

  const FloatingBob({super.key, required this.child, this.distance = 6});

  @override
  State<FloatingBob> createState() => _FloatingBobState();
}

class _FloatingBobState extends State<FloatingBob> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, (Curves.easeInOut.transform(_c.value) - 0.5) * widget.distance * 2),
        child: child,
      ),
      child: widget.child,
    );
  }
}
