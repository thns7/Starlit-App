import 'package:flutter/material.dart';
import 'package:starlitfilms/models/review.dart';

const starColor = Color(0xff9670F5);

class StarRow extends StatelessWidget {
  final int rating;
  final double size;

  const StarRow({super.key, required this.rating, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star : Icons.star_border,
          color: starColor,
          size: size,
        ),
      ),
    );
  }
}

/// Fundo com o pôster do filme (ou um gradiente se não houver pôster).
class MoviePosterBackground extends StatelessWidget {
  final String? posterUrl;
  final Widget child;

  const MoviePosterBackground({super.key, this.posterUrl, required this.child});

  @override
  Widget build(BuildContext context) {
    final hasPoster = posterUrl != null && posterUrl!.isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF462F7E), Color(0xFF1E1240)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        if (hasPoster)
          Image.network(
            posterUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        Container(color: Colors.black.withOpacity(hasPoster ? 0.6 : 0.2)),
        child,
      ],
    );
  }
}

/// Card usado na grade da home.
class ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onTap;

  const ReviewCard({super.key, required this.review, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: MoviePosterBackground(
            posterUrl: review.movie.posterUrl,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.movie.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  StarRow(rating: review.rating, size: 18),
                  const SizedBox(height: 5),
                  Expanded(
                    child: Text(
                      review.content,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        review.likedByMe ? Icons.favorite : Icons.favorite_border,
                        color: starColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text('${review.likeCount}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.chat_bubble_outline, color: starColor, size: 16),
                      const SizedBox(width: 4),
                      Text('${review.commentCount}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '@${review.author.username}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Item de lista usado no perfil.
class ReviewListTile extends StatelessWidget {
  final Review review;
  final VoidCallback onTap;

  const ReviewListTile({super.key, required this.review, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF3A267F),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.movie.title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!review.isPublic)
                  const Icon(Icons.lock, color: Colors.white54, size: 16),
              ],
            ),
            const SizedBox(height: 5),
            StarRow(rating: review.rating, size: 18),
            const SizedBox(height: 5),
            Text(
              review.content,
              style: const TextStyle(color: Colors.white70),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '♥ ${review.likeCount}   💬 ${review.commentCount}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
