import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/movie_picker.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/services/supabase_service.dart';
import 'package:starlitfilms/theme/tokens.dart';

/// Abre o formulário de nova review. Retorna true se uma review foi publicada.
Future<bool> showNewReviewSheet(BuildContext context,
    {Movie? initialMovie}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    builder: (context) => NewReviewSheet(initialMovie: initialMovie),
  );
  return result ?? false;
}

class NewReviewSheet extends StatefulWidget {
  final Movie? initialMovie;

  const NewReviewSheet({super.key, this.initialMovie});

  @override
  State<NewReviewSheet> createState() => _NewReviewSheetState();
}

class _NewReviewSheetState extends State<NewReviewSheet> {
  final _service = SupabaseService.instance;
  final _contentController = TextEditingController();

  late Movie? _selectedMovie = widget.initialMovie;
  int _rating = 0;
  bool _isPublic = true;
  bool _saving = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SC.danger),
    );
  }

  final _maxBurst = GlobalKey<StarBurstState>();

  void _rate(int value) {
    HapticFeedback.selectionClick();
    setState(() => _rating = value);
    if (value == 5 && !SMotion.reduced(context)) {
      Future.delayed(const Duration(milliseconds: 200), () => _maxBurst.currentState?.fire());
    }
  }

  Future<void> _pickMovie() async {
    final movie = await Navigator.push<Movie>(
      context,
      MaterialPageRoute(builder: (_) => const MoviePickerPage()),
    );
    if (movie != null && mounted) setState(() => _selectedMovie = movie);
  }

  Future<void> _publish() async {
    if (_selectedMovie == null) {
      _showError('Selecione um filme.');
      return;
    }
    if (_rating == 0) {
      _showError('Dê uma nota de 1 a 5 estrelas.');
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      _showError('Escreva sua review.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.createReview(
        movieId: _selectedMovie!.id,
        content: _contentController.text,
        rating: _rating,
        isPublic: _isPublic,
      );
      if (!mounted) return;
      showStarlitToast(context, 'Review publicada!', icon: Icons.auto_awesome_rounded);
      Navigator.of(context).pop(true);
    } catch (e) {
      _showError(friendlyError(e));
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _ratingWords = ['', 'Ruim', 'Fraco', 'Bom', 'Muito bom', 'Obra-prima'];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final movie = _selectedMovie;
    return Container(
      decoration: const BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(SRadius.xl)),
      ),
      padding: EdgeInsets.fromLTRB(SSpace.page, 10, SSpace.page, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SC.outline,
                    borderRadius: BorderRadius.circular(SRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nova review',
                style: TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.4),
              ),
              const SizedBox(height: 16),
              Pressable(
                onTap: _pickMovie,
                pressedScale: 0.98,
                semanticLabel: 'Escolher filme',
                child: AnimatedContainer(
                  duration: SMotion.of(context, SMotion.medium),
                  curve: SMotion.emphasized,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SC.surfaceHigh,
                    borderRadius: BorderRadius.circular(SRadius.lg),
                    border: Border.all(
                      color: movie == null ? SC.outline.withValues(alpha: 0.5) : SC.star,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(SRadius.sm),
                        child: SizedBox(
                          width: 48,
                          height: 72,
                          child: PosterImage(url: movie?.posterUrl),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie?.title ?? 'Qual filme você viu?',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: movie == null ? SC.textMuted : SC.text,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              movie == null
                                  ? 'Toque para buscar'
                                  : (movie.year?.toString() ?? 'Trocar filme'),
                              style: const TextStyle(color: SC.textFaint, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Icon(movie == null ? Icons.search_rounded : Icons.swap_horiz_rounded,
                          color: SC.textMuted),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final on = index < _rating;
                  return Semantics(
                    button: true,
                    label: '${index + 1} estrelas',
                    child: GestureDetector(
                      onTap: () => _rate(index + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _PopStar(
                          on: on,
                          // Cascata: as estrelas acendem da esquerda para a direita.
                          delay: Duration(milliseconds: 45 * index),
                          burst: index == 4 ? _maxBurst : null,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: SMotion.of(context, SMotion.quick),
                child: Text(
                  _rating == 0 ? 'Toque nas estrelas para dar sua nota' : _ratingWords[_rating],
                  key: ValueKey(_rating),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _rating == 0 ? SC.textFaint : SC.starSoft,
                    fontWeight: _rating == 0 ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _contentController,
                maxLines: 5,
                minLines: 3,
                maxLength: 5000,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: SC.text, height: 1.45),
                decoration: const InputDecoration(
                  hintText: 'O que você achou do filme?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 6),
              _VisibilityToggle(
                isPublic: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Publicar review',
                icon: Icons.send_rounded,
                loading: _saving,
                onPressed: _publish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seletor segmentado Pública / Só amigos com indicador deslizante.
class _VisibilityToggle extends StatelessWidget {
  final bool isPublic;
  final ValueChanged<bool> onChanged;

  const _VisibilityToggle({required this.isPublic, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget option(bool value, IconData icon, String label) {
      final selected = isPublic == value;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: selected ? SC.text : SC.textFaint),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      color: selected ? SC.text : SC.textFaint,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SC.surfaceHigh,
        borderRadius: BorderRadius.circular(SRadius.md),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: isPublic ? Alignment.centerLeft : Alignment.centerRight,
            duration: SMotion.of(context, SMotion.medium),
            curve: SMotion.emphasized,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: SC.surfaceHigher,
                  borderRadius: BorderRadius.circular(SRadius.sm),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              option(true, Icons.public_rounded, 'Pública'),
              option(false, Icons.group_rounded, 'Só amigos'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Estrela da nota: ao acender, "pula" (escala 1 → 1.3 → 1) com leve atraso
/// em cascata; ao apagar, volta sem pulo.
class _PopStar extends StatefulWidget {
  final bool on;
  final Duration delay;
  final GlobalKey<StarBurstState>? burst;

  const _PopStar({required this.on, required this.delay, this.burst});

  @override
  State<_PopStar> createState() => _PopStarState();
}

class _PopStarState extends State<_PopStar> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: SMotion.easeOut)), weight: 40),
    TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: SMotion.easeOut)), weight: 60),
  ]).animate(_c);

  @override
  void didUpdateWidget(_PopStar old) {
    super.didUpdateWidget(old);
    if (!old.on && widget.on && !SMotion.reduced(context)) {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final star = ScaleTransition(
      scale: _scale,
      child: AnimatedSwitcher(
        duration: SMotion.of(context, const Duration(milliseconds: 160)),
        child: Icon(
          widget.on ? Icons.star_rounded : Icons.star_outline_rounded,
          key: ValueKey(widget.on),
          color: widget.on ? SC.gold : SC.textFaint,
          size: 40,
        ),
      ),
    );
    return widget.burst == null
        ? star
        : StarBurst(key: widget.burst, radius: 34, color: SC.gold, child: star);
  }
}
