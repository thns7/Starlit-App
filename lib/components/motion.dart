import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          curve: SMotion.easeOut,
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
    this.offsetY = 12,
    this.baseDelay = Duration.zero,
  });

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: SMotion.easeOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (SMotion.reduced(context)) {
      _c.value = 1;
      return;
    }
    // Cascata limitada: 40ms entre itens, no máximo 6 passos.
    final delay = widget.baseDelay +
        Duration(milliseconds: 40 * math.min(widget.index, 6));
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
      AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: SMotion.easeOut)),
        weight: 35),
    TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: SMotion.easeOut)),
        weight: 65),
  ]).animate(_c);

  final _burst = GlobalKey<StarBurstState>();

  @override
  void didUpdateWidget(LikeButton old) {
    super.didUpdateWidget(old);
    if (!old.liked && widget.liked) {
      HapticFeedback.lightImpact();
      if (!SMotion.reduced(context)) {
        _c.forward(from: 0);
        _burst.currentState?.fire();
      }
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
            StarBurst(
              key: _burst,
              child: ScaleTransition(
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

/// Voo em arco para Heroes de pôster (em vez de linha reta).
RectTween posterFlight(Rect? begin, Rect? end) =>
    MaterialRectArcTween(begin: begin, end: end);

/// Leve zoom de chegada (1.06 → 1) para imagens de destaque, uma vez por abertura.
class ArrivalZoom extends StatelessWidget {
  final Widget child;

  const ArrivalZoom({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (SMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.06, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: SMotion.easeOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: child,
    );
  }
}

/// Pequena explosão de estrelinhas ao redor do filho (curtir, dar nota máxima).
/// Chame `fire()` pela GlobalKey<StarBurstState>.
class StarBurst extends StatefulWidget {
  final Widget child;
  final int count;
  final double radius;
  final Color color;

  const StarBurst({
    super.key,
    required this.child,
    this.count = 7,
    this.radius = 26,
    this.color = SC.starSoft,
  });

  @override
  State<StarBurst> createState() => StarBurstState();
}

class StarBurstState extends State<StarBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  void fire() => _c.forward(from: 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              if (_c.value == 0 || _c.value == 1) return const SizedBox.shrink();
              final t = SMotion.easeOut.transform(_c.value);
              final fade = 1 - Curves.easeIn.transform(_c.value);
              return SizedBox(
                width: 0,
                height: 0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < widget.count; i++)
                      Builder(builder: (context) {
                        final a = (i / widget.count) * 2 * math.pi - math.pi / 2;
                        final d = widget.radius * (0.35 + 0.65 * t) * (i.isEven ? 1 : 0.8);
                        final size = (i.isEven ? 9.0 : 6.0) * (1 - 0.3 * t);
                        return Positioned(
                          left: math.cos(a) * d - size / 2,
                          top: math.sin(a) * d - size / 2,
                          child: Opacity(
                            opacity: fade.clamp(0, 1),
                            child: Transform.rotate(
                              angle: t * math.pi,
                              child: Icon(Icons.star_rounded,
                                  size: size, color: i.isEven ? widget.color : SC.gold),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Toque duplo para curtir: mostra um coração grande que "estoura" no centro.
class DoubleTapLike extends StatefulWidget {
  final Widget child;
  final VoidCallback onDoubleTap;

  const DoubleTapLike({super.key, required this.child, required this.onDoubleTap});

  @override
  State<DoubleTapLike> createState() => _DoubleTapLikeState();
}

class _DoubleTapLikeState extends State<DoubleTapLike> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.15).chain(CurveTween(curve: SMotion.easeOut)), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 15),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeIn)), weight: 25),
  ]).animate(_c);

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _handle() {
    HapticFeedback.mediumImpact();
    widget.onDoubleTap();
    if (!SMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _handle,
      child: Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.center,
        children: [
          widget.child,
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => _c.value == 0 || _c.value == 1
                  ? const SizedBox.shrink()
                  : Opacity(
                      opacity: _opacity.value,
                      child: Transform.scale(
                        scale: _scale.value,
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 96,
                          color: Colors.white,
                          shadows: [Shadow(color: Color(0x99150B2E), blurRadius: 24)],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de sucesso que desce do topo (entrada 280ms ease-out, saída 180ms ease-in).
void showStarlitToast(BuildContext context, String message,
    {IconData icon = Icons.check_circle_rounded}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(message: message, icon: icon, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  final String message;
  final IconData icon;
  final VoidCallback onDone;

  const _Toast({required this.message, required this.icon, required this.onDone});

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: SMotion.easeOut,
    reverseCurve: Curves.easeIn,
  );
  final _burst = GlobalKey<StarBurstState>();

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (SMotion.reduced(context)) {
        _c.value = 1;
      } else {
        await _c.forward();
        _burst.currentState?.fire();
      }
      await Future.delayed(const Duration(milliseconds: 2200));
      if (!mounted) return;
      if (SMotion.reduced(context)) {
        widget.onDone();
      } else {
        await _c.reverse();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 10;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, child) => Opacity(
            opacity: _t.value.clamp(0, 1),
            child: FractionalTranslation(
              translation: Offset(0, -0.6 * (1 - _t.value)),
              child: Transform.scale(scale: 0.96 + 0.04 * _t.value, child: child),
            ),
          ),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
                decoration: BoxDecoration(
                  color: SC.surfaceHigher,
                  borderRadius: BorderRadius.circular(SRadius.pill),
                  border: Border.all(color: SC.star.withValues(alpha: 0.5)),
                  boxShadow: SShadow.raised,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StarBurst(
                      key: _burst,
                      radius: 20,
                      child: Icon(widget.icon, color: SC.starSoft, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: SC.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
