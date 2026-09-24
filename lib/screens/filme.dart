import 'package:flutter/material.dart';
import 'package:starlitfilms/components/movie_carousel.dart';
import 'package:starlitfilms/components/new_review_sheet.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/models/review.dart';
import 'package:starlitfilms/screens/review.dart';
import 'package:starlitfilms/services/supabase_service.dart';
import 'package:starlitfilms/services/tmdb_service.dart';

/// Detalhes de um filme do TMDB + reviews da comunidade Starlit.
class MovieDetailPage extends StatefulWidget {
  final TmdbMovie movie;

  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  final _service = SupabaseService.instance;
  late TmdbMovie _movie = widget.movie;
  Movie? _local;
  List<Review> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        TmdbService.instance.details(_movie.tmdbId).catchError((_) => _movie),
        _service.findMovieByTmdbId(_movie.tmdbId),
      ]);
      final local = results[1] as Movie?;
      final reviews = local == null
          ? <Review>[]
          : await _service.fetchMovieReviews(local.id);
      if (!mounted) return;
      setState(() {
        _movie = results[0] as TmdbMovie;
        _local = local;
        _reviews = reviews;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _writeReview() async {
    try {
      final local = _local ?? await _service.ensureTmdbMovie(_movie);
      if (!mounted) return;
      if (await showNewReviewSheet(context, initialMovie: local)) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  double? get _starlitAverage {
    if (_reviews.isEmpty) return null;
    return _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
        _reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    final avg = _starlitAverage;
    return Scaffold(
      backgroundColor: const Color(0xFF150B2E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _writeReview,
        backgroundColor: const Color(0xff7E56E4),
        icon: const Icon(Icons.rate_review, color: Colors.white),
        label: const Text('Escrever review',
            style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            SizedBox(
              height: 260,
              child: MoviePosterBackground(
                posterUrl: _movie.backdropUrl ?? _movie.posterUrl,
                child: const SizedBox.shrink(),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -70),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoviePosterCard(movie: _movie, onTap: () {}, width: 110),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _movie.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (_movie.releaseDate != null)
                              Text(
                                'Lançamento: ${formatDate(_movie.releaseDate!)}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            const SizedBox(height: 6),
                            if (_movie.voteAverage > 0)
                              Text(
                                  'TMDB ${_movie.voteAverage.toStringAsFixed(1)}/10',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                            if (avg != null)
                              Row(
                                children: [
                                  StarRow(rating: avg.round(), size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${avg.toStringAsFixed(1)} no Starlit',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_movie.overview.isNotEmpty)
              Transform.translate(
                offset: const Offset(0, -50),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _movie.overview,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Reviews no Starlit',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                      'Ninguém avaliou este filme ainda. Seja o primeiro!',
                      style: TextStyle(color: Colors.white54)),
                ),
              )
            else
              ..._reviews.map((r) => ReviewListTile(
                    review: r,
                    showAuthor: true,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ReviewDetailPage(review: r)),
                      );
                      _load();
                    },
                  )),
          ],
        ),
      ),
    );
  }
}
