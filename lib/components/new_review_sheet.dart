import 'package:flutter/material.dart';
import 'package:starlitfilms/components/movie_picker.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/services/supabase_service.dart';

/// Abre o formulário de nova review. Retorna true se uma review foi publicada.
Future<bool> showNewReviewSheet(BuildContext context,
    {Movie? initialMovie}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
            InkWell(
              onTap: _pickMovie,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A267F),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    if (_selectedMovie?.posterUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          _selectedMovie!.posterUrl!,
                          width: 40,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.movie, color: Colors.white54),
                        ),
                      )
                    else
                      const Icon(Icons.movie, color: Colors.white54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedMovie?.label ?? 'Escolher filme',
                        style: TextStyle(
                          color: _selectedMovie == null
                              ? Colors.white70
                              : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Icon(Icons.search, color: Colors.white70),
                  ],
                ),
              ),
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
                      color: index < _rating
                          ? const Color(0xff7E56E4)
                          : Colors.grey,
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
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
