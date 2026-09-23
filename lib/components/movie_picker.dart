import 'dart:async';

import 'package:flutter/material.dart';
import 'package:starlitfilms/config.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/services/supabase_service.dart';
import 'package:starlitfilms/services/tmdb_service.dart';

const _bg = Color(0xFF150B2E);

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
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
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
            backgroundColor: _bg,
            title: const Text('Adicionar filme',
                style: TextStyle(color: Colors.white)),
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
                    style: TextStyle(color: Colors.white70)),
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
                            backgroundColor: Colors.red,
                          ));
                        }
                      },
                child: const Text('Adicionar',
                    style: TextStyle(color: Color(0xff7E56E4))),
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
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _poster(String? url) {
    const placeholder = SizedBox(
      width: 46,
      height: 69,
      child: ColoredBox(
        color: Color(0xFF3A267F),
        child: Icon(Icons.movie, color: Colors.white38),
      ),
    );
    if (url == null || url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(url,
          width: 46,
          height: 69,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useTmdb = AppConfig.hasTmdb;
    final isEmpty = useTmdb ? _tmdbResults.isEmpty : _localResults.isEmpty;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A1266),
        iconTheme: const IconThemeData(color: Colors.white),
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), _search);
          },
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Buscar filme',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_loading && isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
              ),
            )
          else
            ListView(
              children: [
                if (useTmdb && _controller.text.trim().isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Em alta nesta semana',
                        style: TextStyle(color: Colors.white54)),
                  ),
                if (isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Nenhum filme encontrado.',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                if (useTmdb)
                  ..._tmdbResults.map((m) => ListTile(
                        onTap: _selecting ? null : () => _selectTmdb(m),
                        leading: _poster(m.posterUrl),
                        title: Text(m.title,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          m.year?.toString() ?? 'Sem data',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ))
                else ...[
                  ..._localResults.map((m) => ListTile(
                        onTap: () => Navigator.of(context).pop(m),
                        leading: _poster(m.posterUrl),
                        title: Text(m.title,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(m.year?.toString() ?? '',
                            style: const TextStyle(color: Colors.white54)),
                      )),
                  ListTile(
                    onTap: _addMovieManually,
                    leading: const Icon(Icons.add_circle,
                        color: Color(0xff9670F5), size: 36),
                    title: const Text('Não encontrou? Adicionar filme',
                        style: TextStyle(color: Color(0xff9670F5))),
                  ),
                ],
              ],
            ),
          if (_selecting)
            const ColoredBox(
              color: Colors.black45,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
