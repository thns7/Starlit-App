import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlitfilms/theme/tokens.dart';

class NotchNavItem {
  final String asset;
  final double iconWidth;
  final String label;

  const NotchNavItem(this.asset, this.label, {this.iconWidth = 24});
}

/// Barra inferior com o "notch" do Starlit: um círculo flutuante que carrega o
/// ícone da aba ativa. Ao trocar de aba, o recorte da barra e o círculo deslizam
/// juntos (o círculo levanta, desliza e pousa) e o ícone é trocado dentro
/// do círculo. Interrompível: um toque no meio da animação parte da posição atual.
class NotchNavBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final List<NotchNavItem> items;

  const NotchNavBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.items,
  });

  static const barColor = Color(0xFF2C2247);
  static const notchColor = Color(0xFF42326A);

  @override
  State<NotchNavBar> createState() => _NotchNavBarState();
}

class _NotchNavBarState extends State<NotchNavBar> with SingleTickerProviderStateMixin {
  static const _barHeight = 64.0;
  static const _circle = 54.0;
  static const _rise = 20.0; // quanto o círculo sobe acima da barra
  static const _lift = 10.0; // o círculo levanta no meio do trajeto

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  late double _from = widget.index.toDouble();
  late double _to = widget.index.toDouble();

  /// Posição (em "slots") do notch neste frame.
  double get _pos => _from + (_to - _from) * SMotion.easeInOut.transform(_c.value);

  @override
  void didUpdateWidget(NotchNavBar old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index) {
      // Parte de onde o notch está agora, mesmo no meio de outra animação.
      _from = _c.isAnimating ? _pos : old.index.toDouble();
      _to = widget.index.toDouble();
      if (SMotion.reduced(context)) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _icon(NotchNavItem item, {double scale = 1}) {
    return Image.asset(
      item.asset,
      width: item.iconWidth * scale,
      filterQuality: FilterQuality.high,
      color: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final n = widget.items.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, math.max(bottomInset, 12)),
      child: SizedBox(
        height: _barHeight + _rise,
        child: LayoutBuilder(
          builder: (context, c) {
            const inset = 16.0;
            final slot = (c.maxWidth - inset * 2) / n;
            return AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                final pos = _pos;
                final cx = inset + slot * (pos + 0.5);
                // Levanta: zero nas pontas, máximo no meio do trajeto.
                final moving = (_to - _from).abs() > 0.01;
                final lift = moving ? math.sin(math.pi * t) * _lift : 0.0;
                // Fundo do círculo em coordenadas da barra + folga de 6px.
                final notchDepth = _circle - _rise + 6 - lift * 1.8;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Barra com o recorte acompanhando o notch.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _barHeight,
                      child: CustomPaint(
                        painter: _BarPainter(
                          notchX: cx,
                          notchRadius: _circle / 2 + 6,
                          notchDepth: notchDepth,
                        ),
                      ),
                    ),
                    // Ícones da barra (o da aba ativa some; os outros sobem de volta).
                    for (var i = 0; i < n; i++)
                      Positioned(
                        left: inset + slot * i,
                        width: slot,
                        bottom: 0,
                        height: _barHeight,
                        child: _BarSlot(
                          selected: i == widget.index,
                          label: widget.items[i].label,
                          onTap: () => widget.onSelect(i),
                          child: _icon(widget.items[i]),
                        ),
                      ),
                    // Círculo flutuante com o ícone ativo.
                    Positioned(
                      left: cx - _circle / 2,
                      top: -lift,
                      width: _circle,
                      height: _circle,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: NotchNavBar.notchColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF05020D).withValues(alpha: 0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: SMotion.of(context, const Duration(milliseconds: 220)),
                              switchInCurve: SMotion.easeOut,
                              switchOutCurve: SMotion.easeOut,
                              transitionBuilder: (child, a) => FadeTransition(
                                opacity: a,
                                child: ScaleTransition(
                                  scale: Tween(begin: 0.9, end: 1.0).animate(a),
                                  child: child,
                                ),
                              ),
                              child: KeyedSubtree(
                                key: ValueKey(widget.index),
                                child: _icon(widget.items[widget.index], scale: 1.1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Um slot da barra: some quando ativo e reaparece subindo quando deixa de ser.
/// Toque encolhe o ícone levemente (retorno imediato).
class _BarSlot extends StatefulWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  const _BarSlot({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
  });

  @override
  State<_BarSlot> createState() => _BarSlotState();
}

class _BarSlotState extends State<_BarSlot> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final d = SMotion.of(context, const Duration(milliseconds: 220));
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          if (!widget.selected) HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: Center(
          child: AnimatedScale(
            scale: _down ? 0.88 : 1,
            duration: SMotion.of(context, SMotion.tap),
            curve: SMotion.easeOut,
            child: AnimatedSlide(
              offset: widget.selected ? const Offset(0, 0.6) : Offset.zero,
              duration: d,
              curve: SMotion.easeOut,
              child: AnimatedOpacity(
                opacity: widget.selected ? 0 : 0.7,
                duration: d,
                curve: SMotion.easeOut,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra arredondada com um recorte côncavo suave sob o círculo.
class _BarPainter extends CustomPainter {
  final double notchX;
  final double notchRadius;
  final double notchDepth; // profundidade do recorte em px

  _BarPainter({required this.notchX, required this.notchRadius, required this.notchDepth});

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 28.0;
    final r = notchRadius;
    final depth = notchDepth.clamp(8.0, r + 10);
    const shoulder = 8.0;
    final x = notchX;
    // Perto dos cantos, o recorte começa logo depois da curva do canto.
    final left = math.max(radius, x - r - shoulder);
    final right = math.min(size.width - radius, x + r + shoulder);

    final path = Path()
      ..moveTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(left, 0)
      ..cubicTo(x - r * 0.9, 0, x - r, depth, x, depth)
      ..cubicTo(x + r, depth, x + r * 0.9, 0, right, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(size.width, size.height, size.width - radius, size.height)
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..close();

    canvas.drawShadow(path, const Color(0xFF05020D), 8, false);
    canvas.drawPath(path, Paint()..color = NotchNavBar.barColor);
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.notchX != notchX || old.notchRadius != notchRadius || old.notchDepth != notchDepth;
}
