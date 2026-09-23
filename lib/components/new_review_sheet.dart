import 'package:flutter/material.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/services/supabase_service.dart';

/// Abre o formulário de nova review. Retorna true se uma review foi publicada.
Future<bool> showNewReviewSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const NewReviewSheet(),
  );
  return result ?? false;
}

class NewReviewSheet extends StatefulWidget {
  const NewReviewSheet({super.key});

  @override
  State<NewReviewSheet> createState() => _NewReviewSheetState();
}

class _NewReviewSheetState extends State<NewReviewSheet> {
  final _service = SupabaseService.instance;
  final _contentController = TextEditingController();

  List<Movie> _movies = [];
  Movie? _selectedMovie;
  int _rating = 0;
  bool _isPublic = true;
  bool _loadingMovies = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadMovies() async {
    try {
      final movies = await _service.fetchMovies();
      if (mounted) setState(() => _movies = movies);
    } catch (e) {
      _showError(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loadingMovies = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _addMovieDialog() async {
    final titleController = TextEditingController();
    final yearController = TextEditingController();
    final posterController = TextEditingController();

    final created = await showDialog<Movie>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF150B2E),
            title: const Text('Adicionar filme', style: TextStyle(color: Colors.white)),
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
                child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
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
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(movie);
                          }
                        } catch (e) {
                          setDialogState(() => saving = false);
                          _showError(friendlyError(e) == 'Esse registro já existe.'
                              ? 'Esse filme já está na lista.'
                              : friendlyError(e));
                        }
                      },
                child: const Text('Adicionar', style: TextStyle(color: Color(0xff7E56E4))),
              ),
            ],
          ),
        );
      },
    );

    if (created != null && mounted) {
      setState(() {
        _movies = [..._movies, created]
          ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        _selectedMovie = created;
      });
    }
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
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError(friendlyError(e));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A1266), Color(0xFF150B2E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Criar Novo Post',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            if (_loadingMovies)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Movie>(
                      value: _selectedMovie,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white),
                      dropdownColor: const Color(0xFF3A267F),
                      decoration: InputDecoration(
                        hintText: 'Selecione o filme',
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF3A267F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _movies
                          .map((m) => DropdownMenuItem<Movie>(
                                value: m,
                                child: Text(m.label, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedMovie = value),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Adicionar filme',
                    icon: const Icon(Icons.add_circle, color: Color(0xff9670F5), size: 32),
                    onPressed: _addMovieDialog,
                  ),
                ],
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _contentController,
              maxLines: 4,
              maxLength: 5000,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'O que você achou do filme?',
                hintStyle: const TextStyle(color: Colors.white70),
                counterStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF3A267F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: _isPublic ? 'Pública' : 'Só para amigos',
                  icon: Icon(
                    _isPublic ? Icons.public : Icons.group,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => setState(() => _isPublic = !_isPublic),
                ),
                const SizedBox(width: 10),
                ...List.generate(5, (index) {
                  return IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.star,
                      color: index < _rating ? const Color(0xff7E56E4) : Colors.grey,
                      size: 32,
                    ),
                    onPressed: () => setState(() => _rating = index + 1),
                  );
                }),
              ],
            ),
            Text(
              _isPublic ? 'Visível para todos' : 'Visível só para seus amigos',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff7E56E4),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 10,
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Publicar',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
