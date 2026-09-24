import 'package:flutter/material.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/models/review.dart';
import 'package:starlitfilms/theme/tokens.dart';

const starColor = SC.star;

class StarRow extends StatelessWidget {
  final int rating;
  final double size;

  const StarRow({super.key, required this.rating, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rating de 5 estrelas',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (i) => Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: i < rating ? SC.gold : SC.textFaint,
            size: size,
          ),
        ),
      ),
    );
  }
}

/// Imagem de rede com placeholder da marca (ícone de filme sobre violeta).
class PosterImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;

  const PosterImage({super.key, this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [SC.surfaceHigher, SC.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(child: Icon(Icons.movie_rounded, color: SC.textFaint, size: 36)),
        );
    if (url == null || url!.isEmpty) return placeholder();
    return Image.network(
      url!,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder(),
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: SMotion.of(context, SMotion.medium),
          curve: SMotion.standard,
          child: child,
        );
      },
    );
  }
}

/// Fundo com o pôster do filme escurecido (ou gradiente sem pôster).
class MoviePosterBackground extends StatelessWidget {
  final String? posterUrl;
  final Widget child;

  const MoviePosterBackground({super.key, this.posterUrl, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PosterImage(url: posterUrl),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33150B2E), Color(0x99150B2E), SC.bg],
              stops: [0, 0.6, 1],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Card da grade da home: pôster em destaque, nota e trecho da review.
class ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onTap;

  const ReviewCard({super.key, required this.review, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Review de ${review.movie.title} por @${review.author.username}',
      child: Container(
        decoration: BoxDecoration(
          color: SC.surface,
          borderRadius: BorderRadius.circular(SRadius.lg),
          boxShadow: SShadow.card,
          border: Border.all(color: SC.outline.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 11,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'review-poster-${review.id}',
                    createRectTween: posterFlight,
                    child: PosterImage(url: review.movie.posterUrl),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xE6150B2E)],
                        stops: [0.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SC.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StarRow(rating: review.rating, size: 15),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        review.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: SC.textMuted, fontSize: 12.5, height: 1.4),
                      ),
                    ),
                    Row(
                      children: [
                        UserAvatar.of(review.author, radius: 10),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '@${review.author.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: SC.text, fontSize: 11.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Icon(
                          review.likedByMe
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: review.likedByMe ? SC.star : SC.textFaint,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text('${review.likeCount}',
                            style: const TextStyle(color: SC.textMuted, fontSize: 11.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grade com skeletons enquanto as reviews carregam.
class ReviewGridSkeleton extends StatelessWidget {
  const ReviewGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: SSpace.page),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 4,
      gridDelegate: reviewGridDelegate,
      itemBuilder: (_, __) => const Skeleton(radius: SRadius.lg),
    );
  }
}

const reviewGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  childAspectRatio: 0.56,
  crossAxisSpacing: 14,
  mainAxisSpacing: 14,
);

/// Item de lista (perfil, página do filme).
class ReviewListTile extends StatelessWidget {
  final Review review;
  final VoidCallback onTap;
  final bool showAuthor;

  const ReviewListTile({
    super.key,
    required this.review,
    required this.onTap,
    this.showAuthor = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SC.surface,
          borderRadius: BorderRadius.circular(SRadius.lg),
          border: Border.all(color: SC.outline.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(SRadius.sm),
              child: SizedBox(
                width: 54,
                height: 80,
                child: showAuthor
                    ? Center(child: UserAvatar.of(review.author, radius: 22))
                    : PosterImage(url: review.movie.posterUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          showAuthor ? '@${review.author.username}' : review.movie.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600, color: SC.text),
                        ),
                      ),
                      if (!review.isPublic)
                        const Tooltip(
                          message: 'Só para amigos',
                          child: Icon(Icons.group_rounded, color: SC.textFaint, size: 16),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  StarRow(rating: review.rating, size: 15),
                  const SizedBox(height: 6),
                  Text(
                    review.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: SC.textMuted, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, size: 14, color: SC.textFaint),
                      const SizedBox(width: 4),
                      Text('${review.likeCount}',
                          style: const TextStyle(color: SC.textFaint, fontSize: 12)),
                      const SizedBox(width: 14),
                      const Icon(Icons.chat_bubble_rounded, size: 13, color: SC.textFaint),
                      const SizedBox(width: 4),
                      Text('${review.commentCount}',
                          style: const TextStyle(color: SC.textFaint, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
