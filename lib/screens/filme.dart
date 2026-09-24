import 'package:flutter/material.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/movie_carousel.dart';
import 'package:starlitfilms/components/new_review_sheet.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/models/review.dart';
import 'package:starlitfilms/screens/review.dart';
import 'package:starlitfilms/services/supabase_service.dart';
import 'package:starlitfilms/services/tmdb_service.dart';
import 'package:starlitfilms/theme/tokens.dart';

/// Detalhes de um filme do TMDB + reviews da comunidade Starlit.
class MovieDetailPage extends StatefulWidget {
  final TmdbMovie movie;
  final String? heroTag;

  const MovieDetailPage({super.key, required this.movie, this.heroTag});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  final _service = SupabaseService.instance;
  late TmdbMovie _movie = widget.movie;
  Movie? _local;
  List<Review> _reviews = [];
  bool _loading = true;
  bool _opening = false;

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
      final reviews =
          local == null ? <Review>[] : await _service.fetchMovieReviews(local.id);
      if (!mounted) return;
      setState(() {
        _movie = results[0] as TmdbMovie;
        _local = local;
        _reviews = reviews;
      });
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyError(e)), backgroundColor: SC.danger),
    );
  }

  Future<void> _writeReview() async {
    setState(() => _opening = true);
    try {
      final local = _local ?? await _service.ensureTmdbMovie(_movie);
      if (!mounted) return;
      setState(() => _opening = false);
      if (await showNewReviewSheet(context, initialMovie: local)) _load();
    } catch (e) {
      if (mounted) setState(() => _opening = false);
      _showError(e);
    }
  }

  double? get _starlitAverage {
    if (_reviews.isEmpty) return null;
    return _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    final avg = _starlitAverage;
    final width = MediaQuery.sizeOf(context).width;
    const posterW = 118.0;

    Widget poster = ClipRRect(
      borderRadius: BorderRadius.circular(SRadius.md),
      child: PosterImage(url: _movie.posterUrl),
    );
    poster = Hero(
      tag: widget.heroTag ?? 'poster-detail-${_movie.tmdbId}',
      createRectTween: posterFlight,
      child: poster,
    );

    return Scaffold(
      backgroundColor: SC.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(backgroundColor: SC.bg.withValues(alpha: 0.6)),
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(SSpace.page, 8, SSpace.page, 12),
        child: PrimaryButton(
          label: 'Escrever review',
          icon: Icons.rate_review_rounded,
          loading: _opening,
          onPressed: _writeReview,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: SC.star,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            SizedBox(
              height: 300,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: ArrivalZoom(
                        child: MoviePosterBackground(
                          posterUrl: _movie.backdropUrl ?? _movie.posterUrl,
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: SSpace.page,
                    bottom: -60,
                    width: posterW,
                    height: posterW * 1.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(SRadius.md),
                        boxShadow: SShadow.raised,
                      ),
                      child: poster,
                    ),
                  ),
                  Positioned(
                    left: SSpace.page + posterW + 16,
                    right: SSpace.page,
                    bottom: -54,
                    child: Entrance(
                      baseDelay: const Duration(milliseconds: 180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _movie.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: SC.text,
                              fontSize: width < 360 ? 19 : 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (_movie.releaseDate != null)
                                _Chip(Icons.calendar_today_rounded,
                                    formatDate(_movie.releaseDate!)),
                              if (_movie.voteAverage > 0)
                                _Chip(Icons.star_rounded,
                                    'TMDB ${_movie.voteAverage.toStringAsFixed(1)}',
                                    iconColor: SC.gold),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
            if (avg != null)
              Entrance(
                index: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(SSpace.page, 0, SSpace.page, 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SC.surface,
                      borderRadius: BorderRadius.circular(SRadius.lg),
                      border: Border.all(color: SC.outline.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          avg.toStringAsFixed(1),
                          style: const TextStyle(
                              color: SC.text, fontSize: 28, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StarRow(rating: avg.round(), size: 18),
                              Text(
                                'Média de ${_reviews.length} ${_reviews.length == 1 ? 'review' : 'reviews'} no Starlit',
                                style: const TextStyle(color: SC.textMuted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_movie.overview.isNotEmpty)
              Entrance(
                index: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(SSpace.page, 12, SSpace.page, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sinopse',
                          style: TextStyle(
                              color: SC.text, fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        _movie.overview,
                        style: const TextStyle(color: SC.textMuted, fontSize: 14.5, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            const SectionHeader('Reviews no Starlit'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SSpace.page),
              child: _loading
                  ? const Column(children: [
                      Skeleton(height: 104, radius: SRadius.lg),
                      SizedBox(height: 12),
                      Skeleton(height: 104, radius: SRadius.lg),
                    ])
                  : _reviews.isEmpty
                      ? const EmptyState(
                          icon: Icons.auto_awesome_rounded,
                          title: 'Ninguém avaliou este filme ainda',
                          message: 'A primeira review é sua.',
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < _reviews.length; i++)
                              Entrance(
                                index: i,
                                child: ReviewListTile(
                                  review: _reviews[i],
                                  showAuthor: true,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              ReviewDetailPage(review: _reviews[i])),
                                    );
                                    _load();
                                  },
                                ),
                              ),
                          ],
                        ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _Chip(this.icon, this.label, {this.iconColor = SC.starSoft});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SC.surfaceHigh,
        borderRadius: BorderRadius.circular(SRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: SC.text, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
