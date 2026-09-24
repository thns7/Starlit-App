import 'package:flutter/material.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/theme/tokens.dart';

String formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

const _months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String posterHeroTag(String scope, int tmdbId) => 'poster-$scope-$tmdbId';

/// Pôster com título, usado nos carrosséis.
class MoviePosterCard extends StatelessWidget {
  final TmdbMovie movie;
  final VoidCallback onTap;
  final bool showReleaseDate;
  final double width;
  final String? heroTag;

  const MoviePosterCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.showReleaseDate = false,
    this.width = 124,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    Widget poster = ClipRRect(
      borderRadius: BorderRadius.circular(SRadius.md),
      child: PosterImage(url: movie.posterUrl),
    );
    if (heroTag != null) {
      poster = Hero(tag: heroTag!, createRectTween: posterFlight, child: poster);
    }

    return Pressable(
      onTap: onTap,
      semanticLabel: movie.title,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SRadius.md),
                      boxShadow: SShadow.card,
                    ),
                    child: poster,
                  ),
                  if (movie.voteAverage > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: SC.bg.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(SRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: SC.gold, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              movie.voteAverage.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: SC.text, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: SC.text, fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.25),
            ),
            if (showReleaseDate && movie.releaseDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Estreia ${shortDate(movie.releaseDate!)}',
                  style: const TextStyle(
                      color: SC.starSoft, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SSpace.page, 20, SSpace.page - 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: SC.text,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Seção horizontal ("Em cartaz", "Em breve"...).
class MovieCarousel extends StatelessWidget {
  final String title;
  final Future<List<TmdbMovie>> future;
  final void Function(TmdbMovie movie, String heroTag) onTap;
  final bool showReleaseDate;

  const MovieCarousel({
    super.key,
    required this.title,
    required this.future,
    required this.onTap,
    this.showReleaseDate = false,
  });

  static const _height = 248.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title),
        SizedBox(
          height: _height,
          child: FutureBuilder<List<TmdbMovie>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SSpace.page),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: SC.textFaint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${snapshot.error}',
                            style: const TextStyle(color: SC.textMuted)),
                      ),
                    ],
                  ),
                );
              }
              final loading = !snapshot.hasData;
              final movies = snapshot.data ?? const <TmdbMovie>[];
              if (!loading && movies.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: SSpace.page),
                  child: Text('Nenhum filme encontrado.',
                      style: TextStyle(color: SC.textMuted)),
                );
              }
              return AnimatedSwitcher(
                duration: SMotion.of(context, SMotion.medium),
                child: ListView.separated(
                  key: ValueKey(loading),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: SSpace.page),
                  itemCount: loading ? 5 : movies.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) {
                    if (loading) {
                      return const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 124, height: 186),
                          SizedBox(height: 10),
                          Skeleton(width: 96, height: 12, radius: 6),
                          SizedBox(height: 6),
                          Skeleton(width: 64, height: 10, radius: 6),
                        ],
                      );
                    }
                    final tag = posterHeroTag(title, movies[i].tmdbId);
                    return Entrance(
                      index: i,
                      offsetY: 0,
                      child: MoviePosterCard(
                        movie: movies[i],
                        showReleaseDate: showReleaseDate,
                        heroTag: tag,
                        onTap: () => onTap(movies[i], tag),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
