import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/theme/tokens.dart';

class BannerAction {
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const BannerAction(this.label, this.onPressed, {this.primary = false});
}

/// Notificação pop-up no topo (estilo iOS): desce com ease-out, some sozinha
/// em 5s, pode ser tocada (abre algo) ou arrastada para cima para dispensar.
void showStarlitBanner(
  OverlayState overlay, {
  required String title,
  required String body,
  String? avatarUrl,
  IconData icon = Icons.notifications_rounded,
  VoidCallback? onTap,
  List<BannerAction> actions = const [],
}) {
  late OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _Banner(
      title: title,
      body: body,
      avatarUrl: avatarUrl,
      icon: icon,
      onTap: onTap,
      actions: actions,
      onDone: remove,
    ),
  );
  overlay.insert(entry);
}

class _Banner extends StatefulWidget {
  final String title;
  final String body;
  final String? avatarUrl;
  final IconData icon;
  final VoidCallback? onTap;
  final List<BannerAction> actions;
  final VoidCallback onDone;

  const _Banner({
    required this.title,
    required this.body,
    required this.avatarUrl,
    required this.icon,
    required this.onTap,
    required this.actions,
    required this.onDone,
  });

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: SMotion.easeOut, reverseCurve: Curves.easeIn);
  Timer? _timer;
  double _drag = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (SMotion.reduced(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
    _timer = Timer(const Duration(seconds: 5), _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    if (SMotion.reduced(context)) {
      widget.onDone();
      return;
    }
    await _c.reverse();
    widget.onDone();
  }

  void _run(VoidCallback f) {
    f();
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 8;
    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) => Opacity(
          opacity: _t.value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, -80 * (1 - _t.value) + _drag),
            child: child,
          ),
        ),
        child: GestureDetector(
          onTap: widget.onTap == null ? null : () => _run(widget.onTap!),
          onVerticalDragUpdate: (d) {
            setState(() => _drag = (_drag + d.delta.dy).clamp(-120.0, 12.0));
          },
          onVerticalDragEnd: (d) {
            if (_drag < -30 || (d.primaryVelocity ?? 0) < -300) {
              _close();
            } else {
              setState(() => _drag = 0);
            }
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: SC.surfaceHigher,
                borderRadius: BorderRadius.circular(SRadius.lg),
                border: Border.all(color: SC.star.withValues(alpha: 0.45)),
                boxShadow: SShadow.raised,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          UserAvatar(url: widget.avatarUrl, radius: 22),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: CircleAvatar(
                              radius: 11,
                              backgroundColor: SC.primary,
                              child: Icon(widget.icon, size: 13, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: SC.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5),
                            ),
                            Text(
                              widget.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Poppins', color: SC.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.actions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final a in widget.actions) ...[
                          Expanded(
                            child: a.primary
                                ? FilledButton(
                                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                                    onPressed: () => _run(a.onPressed),
                                    child: Text(a.label),
                                  )
                                : OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      foregroundColor: SC.text,
                                      side: BorderSide(color: SC.outline.withValues(alpha: 0.8)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(SRadius.md)),
                                    ),
                                    onPressed: () => _run(a.onPressed),
                                    child: Text(a.label),
                                  ),
                          ),
                          if (a != widget.actions.last) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
