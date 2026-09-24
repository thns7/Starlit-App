import 'dart:async';

import 'package:flutter/material.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/config.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/services/supabase_service.dart';
import 'package:starlitfilms/services/tmdb_service.dart';
import 'package:starlitfilms/theme/tokens.dart';


/// Tela de busca de filme. Devolve o [Movie] salvo no banco via Navigator.pop.
class MoviePickerPage extends StatefulWidget {
  const MoviePickerPage({super.key});

  @override
  State<MoviePickerPage> createState() => _MoviePickerPageState();
}

class _MoviePickerPageState extends State<MoviePickerPage> {
  final _service = SupabaseService.instance;
  final _controller = TextEditingController();
  Timer? _debounce;

  List<TmdbMovie> _tmdbResults = [];
  List<Movie> _localResults = [];
  bool _loading = true;
  bool _selecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (AppConfig.hasTmdb) {
        final results = query.trim().isEmpty
            ? await TmdbService.instance.trending()
            : await TmdbService.instance.search(query);
        if (mounted && query == _controller.text)
          setState(() => _tmdbResults = results);
      } else {
        final results = await _service.searchLocalMovies(query);
        if (mounted && query == _controller.text)
          setState(() => _localResults = results);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectTmdb(TmdbMovie movie) async {
    setState(() => _selecting = true);
    try {
      final saved = await _service.ensureTmdbMovie(movie);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _selecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: SC.danger),
      );
    }
  }

  Future<void> _addMovieManually() async {
    final titleController =
        TextEditingController(text: _controller.text.trim());
    final yearController = TextEditingController();
    final posterController = TextEditingController();

    final created = await showDialog<Movie>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            backgroundColor: SC.bg,
            title: const Text('Adicionar filme',
                style: TextStyle(color: SC.text)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(titleController, 'Título'),
                  _dialogField(yearController, 'Ano (opcional)',
                      keyboardType: TextInputType.number),
                  _dialogField(posterController, 'URL do pôster (opcional)',
                      keyboardType: TextInputType.url),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar',
                    style: TextStyle(color: SC.textMuted)),
              ),
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (titleController.text.trim().isEmpty) return;
                        setDialogState(() => saving = true);
                        try {
                          final movie = await _service.addMovie(
                            title: titleController.text,
                            year: int.tryParse(yearController.text.trim()),
                            posterUrl: posterController.text,
                          );
                          if (dialogContext.mounted)
                            Navigator.of(dialogContext).pop(movie);
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (!mounted) return;
                          final msg = friendlyError(e);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(msg == 'Esse registro já existe.'
                                ? 'Esse filme já está na lista.'
                                : msg),
                            backgroundColor: SC.danger,
                          ));
                        }
                      },
                child: const Text('Adicionar',
                    style: TextStyle(color: SC.starSoft)),
              ),
            ],
          ),
        );
      },
    );
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  Widget _dialogField(TextEditingController controller, String label,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: SC.text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: SC.textMuted),
        ),
      ),
    );
  }

  Widget _poster(String? url) => ClipRRect(
        borderRadius: BorderRadius.circular(SRadius.sm),
        child: SizedBox(width: 46, height: 69, child: PosterImage(url: url)),
      );

  @override
  Widget build(BuildContext context) {
    final useTmdb = AppConfig.hasTmdb;
    final isEmpty = useTmdb ? _tmdbResults.isEmpty : _localResults.isEmpty;

    return Scaffold(
      backgroundColor: SC.bg,
      appBar: AppBar(
        backgroundColor: SC.surface,
        shape: Border(bottom: BorderSide(color: SC.outline.withValues(alpha: 0.4))),
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), _search);
          },
          style: const TextStyle(color: SC.text),
          decoration: const InputDecoration(
            hintText: 'Buscar filme',
            prefixIcon: Icon(Icons.search_rounded),
            isDense: true,
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_loading && isEmpty)
            ListView.separated(
              padding: const EdgeInsets.all(SSpace.page),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const Skeleton(height: 72),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SC.textMuted)),
              ),
            )
          else
            ListView(
              children: [
                if (useTmdb && _controller.text.trim().isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Em alta nesta semana',
                        style: TextStyle(color: SC.textFaint)),
                  ),
                if (isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Nenhum filme encontrado.',
                          style: TextStyle(color: SC.textMuted)),
                    ),
                  ),
                if (useTmdb)
                  for (final (i, m) in _tmdbResults.indexed)
                    Entrance(
                      key: ValueKey(m.tmdbId),
                      index: i,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: SSpace.page, vertical: 4),
                        onTap: _selecting ? null : () => _selectTmdb(m),
                        leading: _poster(m.posterUrl),
                        title: Text(m.title,
                            style: const TextStyle(
                                color: SC.text, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          m.year?.toString() ?? 'Sem data',
                          style: const TextStyle(color: SC.textFaint),
                        ),
                        trailing: const Icon(Icons.add_circle_outline_rounded,
                            color: SC.starSoft),
                      ),
                    )
                else ...[
                  ..._localResults.map((m) => ListTile(
                        onTap: () => Navigator.of(context).pop(m),
                        leading: _poster(m.posterUrl),
                        title: Text(m.title,
                            style: const TextStyle(color: SC.text)),
                        subtitle: Text(m.year?.toString() ?? '',
                            style: const TextStyle(color: SC.textFaint)),
                      )),
                  ListTile(
                    onTap: _addMovieManually,
                    leading: const Icon(Icons.add_circle,
                        color: SC.star, size: 36),
                    title: const Text('Não encontrou? Adicionar filme',
                        style: TextStyle(color: SC.star)),
                  ),
                ],
              ],
            ),
          if (_selecting)
            const ColoredBox(
              color: Color(0x88150B2E),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
