import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:starlitfilms/theme/tokens.dart';

/// Resposta tátil: encolhe levemente enquanto pressionado.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final String? semanticLabel;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.semanticLabel,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1,
          duration: SMotion.of(context, SMotion.tap),
          curve: SMotion.standard,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Entrada suave (opacidade + leve subida). O conteúdo nunca fica escondido
/// quando "Reduzir movimento" está ativo.
class Entrance extends StatefulWidget {
  final Widget child;
  final int index;
  final double offsetY;
  final Duration baseDelay;

  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.offsetY = 18,
    this.baseDelay = Duration.zero,
  });

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: SMotion.page);
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: SMotion.emphasized);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (SMotion.reduced(context)) {
      _c.value = 1;
      return;
    }
    // Cascata limitada: no máximo ~6 passos de atraso.
    final delay = widget.baseDelay +
        Duration(milliseconds: 55 * math.min(widget.index, 6));
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _t.value) * widget.offsetY),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Placa de carregamento com brilho que atravessa (skeleton).
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double radius;

  const Skeleton({super.key, this.width, this.height, this.radius = SRadius.md});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

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
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final x = -1.5 + _c.value * 3;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(x - 1, -0.3),
                end: Alignment(x + 1, 0.3),
                colors: const [SC.surfaceHigh, SC.surfaceHigher, SC.surfaceHigh],
                stops: const [0.25, 0.5, 0.75],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Coração que "estoura" ao curtir.
class LikeButton extends StatefulWidget {
  final bool liked;
  final int count;
  final VoidCallback onTap;
  final double size;

  const LikeButton({
    super.key,
    required this.liked,
    required this.count,
    required this.onTap,
    this.size = 24,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35),
    TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: SMotion.emphasized)),
        weight: 65),
  ]).animate(_c);

  @override
  void didUpdateWidget(LikeButton old) {
    super.didUpdateWidget(old);
    if (!old.liked && widget.liked && !SMotion.reduced(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: widget.onTap,
      semanticLabel: widget.liked ? 'Descurtir' : 'Curtir',
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: AnimatedSwitcher(
                duration: SMotion.of(context, SMotion.quick),
                transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
                child: Icon(
                  widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  key: ValueKey(widget.liked),
                  color: widget.liked ? SC.star : SC.textMuted,
                  size: widget.size,
                ),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: SMotion.of(context, SMotion.quick),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                  child: child,
                ),
              ),
              child: Text(
                '${widget.count}',
                key: ValueKey(widget.count),
                style: const TextStyle(color: SC.text, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fundo do céu noturno: gradiente violeta com estrelas que cintilam devagar.
class SkyBackground extends StatefulWidget {
  final Widget child;
  final int starCount;

  const SkyBackground({super.key, required this.child, this.starCount = 70});

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  late final List<_Star> _stars = List.generate(widget.starCount, (i) {
    final r = math.Random(i * 7919);
    return _Star(
      Offset(r.nextDouble(), r.nextDouble()),
      0.4 + r.nextDouble() * 1.2,
      r.nextDouble(),
    );
  });

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
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SC.skyGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _StarPainter(_stars, _c)),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Star {
  final Offset pos;
  final double radius;
  final double phase;
  const _Star(this.pos, this.radius, this.phase);
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final Animation<double> t;

  _StarPainter(this.stars, this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in stars) {
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin((t.value + s.phase) * 2 * math.pi));
      paint.color = SC.starSoft.withValues(alpha: 0.18 + 0.5 * twinkle * (s.radius / 1.6));
      canvas.drawCircle(
        Offset(s.pos.dx * size.width, s.pos.dy * size.height),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.stars != stars;
}

/// Botão principal com gradiente da marca, estado de carregamento e toque.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Pressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      child: AnimatedOpacity(
        duration: SMotion.of(context, SMotion.quick),
        opacity: onPressed == null ? 0.5 : 1,
        child: Container(
          width: expand ? double.infinity : null,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: SC.buttonGradient,
            borderRadius: BorderRadius.circular(SRadius.md),
            boxShadow: enabled ? SShadow.glowButton : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: SMotion.of(context, SMotion.quick),
            child: loading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
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

/// Estado vazio / erro com ícone, texto e ação.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: SC.surfaceHigh,
              borderRadius: BorderRadius.circular(SRadius.lg),
            ),
            child: Icon(icon, color: SC.star, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: SC.text, fontSize: 16, fontWeight: FontWeight.w600)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SC.textMuted, height: 1.45)),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            PrimaryButton(label: actionLabel!, onPressed: onAction, expand: false),
          ],
        ],
      ),
    );
  }
}
