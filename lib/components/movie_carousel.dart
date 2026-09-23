import 'package:flutter/material.dart';
import 'package:starlitfilms/models/movie.dart';

String formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// Pôster com título, usado nos carrosséis.
class MoviePosterCard extends StatelessWidget {
  final TmdbMovie movie;
  final VoidCallback onTap;
  final bool showReleaseDate;
  final double width;

  const MoviePosterCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.showReleaseDate = false,
    this.width = 120,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: movie.posterUrl == null
                    ? _placeholder()
                    : Image.network(
                        movie.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : _placeholder(),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            if (showReleaseDate && movie.releaseDate != null)
              Text(
                formatDate(movie.releaseDate!),
                style: const TextStyle(color: Color(0xff9670F5), fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF3A267F),
      alignment: Alignment.center,
      child: const Icon(Icons.movie, color: Colors.white38, size: 36),
    );
  }
}

/// Seção horizontal com título ("Em cartaz", "Em breve"...).
class MovieCarousel extends StatelessWidget {
  final String title;
  final Future<List<TmdbMovie>> future;
  final void Function(TmdbMovie) onTap;
  final bool showReleaseDate;

  const MovieCarousel({
    super.key,
    required this.title,
    required this.future,
    required this.onTap,
    this.showReleaseDate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 16, 20, 10),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        SizedBox(
          height: 235,
          child: FutureBuilder<List<TmdbMovie>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text('${snapshot.error}',
                      style: const TextStyle(color: Colors.white54)),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final movies = snapshot.data!;
              if (movies.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Text('Nenhum filme encontrado.',
                      style: TextStyle(color: Colors.white54)),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: movies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => MoviePosterCard(
                  movie: movies[i],
                  showReleaseDate: showReleaseDate,
                  onTap: () => onTap(movies[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
