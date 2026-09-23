import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/models/profile.dart';

class Review {
  final int id;
  final String content;
  final int rating;
  final bool isPublic;
  final DateTime createdAt;
  final Profile author;
  final Movie movie;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  const Review({
    required this.id,
    required this.content,
    required this.rating,
    required this.isPublic,
    required this.createdAt,
    required this.author,
    required this.movie,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
  });

  Review copyWith({int? likeCount, bool? likedByMe, int? commentCount}) {
    return Review(
      id: id,
      content: content,
      rating: rating,
      isPublic: isPublic,
      createdAt: createdAt,
      author: author,
      movie: movie,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }

  static int _count(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return (value.first['count'] as int?) ?? 0;
    }
    return 0;
  }

  factory Review.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final myLikes = json['my_like'] as List? ?? const [];
    return Review(
      id: json['id'] as int,
      content: json['content'] as String,
      rating: json['rating'] as int,
      isPublic: json['is_public'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      author: Profile.fromJson(json['author'] as Map<String, dynamic>),
      movie: Movie.fromJson(json['movie'] as Map<String, dynamic>),
      likeCount: _count(json['likes']),
      commentCount: _count(json['comments']),
      likedByMe: currentUserId != null &&
          myLikes.any((l) => l['user_id'] == currentUserId),
    );
  }
}

class Comment {
  final int id;
  final String content;
  final DateTime createdAt;
  final Profile author;
  final int reviewId;
  final String? movieTitle;

  const Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.author,
    required this.reviewId,
    this.movieTitle,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final review = json['review'] as Map<String, dynamic>?;
    final movie = review?['movie'] as Map<String, dynamic>?;
    return Comment(
      id: json['id'] as int,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      author: Profile.fromJson(json['author'] as Map<String, dynamic>),
      reviewId: json['review_id'] as int,
      movieTitle: movie?['title'] as String?,
    );
  }
}
