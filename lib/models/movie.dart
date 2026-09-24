class Movie {
  final int id;
  final String title;
  final int? year;
  final String? posterUrl;
  final int? tmdbId;
  final String? overview;
  final String? backdropUrl;

  const Movie({
    required this.id,
    required this.title,
    this.year,
    this.posterUrl,
    this.tmdbId,
    this.overview,
    this.backdropUrl,
  });

  static const selectFields =
      'id, title, year, poster_url, tmdb_id, overview, backdrop_url';

  @override
  bool operator ==(Object other) => other is Movie && other.id == id;

  @override
  int get hashCode => id.hashCode;

  String get label => year != null ? '$title ($year)' : title;

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as int,
      title: json['title'] as String,
      year: json['year'] as int?,
      posterUrl: json['poster_url'] as String?,
      tmdbId: json['tmdb_id'] as int?,
      overview: json['overview'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
    );
  }
}

/// Filme vindo da API do TMDB (ainda não necessariamente salvo no banco).
class TmdbMovie {
  final int tmdbId;
  final String title;
  final String overview;
  final DateTime? releaseDate;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;

  const TmdbMovie({
    required this.tmdbId,
    required this.title,
    required this.overview,
    this.releaseDate,
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0,
  });

  static const _imageBase = 'https://image.tmdb.org/t/p';

  String? get posterUrl =>
      posterPath == null ? null : '$_imageBase/w500$posterPath';
  String? get backdropUrl =>
      backdropPath == null ? null : '$_imageBase/w780$backdropPath';
  int? get year => releaseDate?.year;
  String get label => year != null ? '$title ($year)' : title;

  factory TmdbMovie.fromJson(Map<String, dynamic> json) {
    final date = json['release_date'] as String?;
    return TmdbMovie(
      tmdbId: json['id'] as int,
      title: (json['title'] ?? json['original_title'] ?? '') as String,
      overview: (json['overview'] as String?) ?? '',
      releaseDate:
          (date == null || date.isEmpty) ? null : DateTime.tryParse(date),
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Monta a partir de um filme já salvo no banco (que veio do TMDB).
  factory TmdbMovie.fromMovie(Movie movie) {
    return TmdbMovie(
      tmdbId: movie.tmdbId!,
      title: movie.title,
      overview: movie.overview ?? '',
      releaseDate: movie.year != null ? DateTime(movie.year!) : null,
      posterPath: _pathOf(movie.posterUrl),
      backdropPath: _pathOf(movie.backdropUrl),
    );
  }

  static String? _pathOf(String? url) {
    if (url == null) return null;
    final i = url.lastIndexOf('/');
    return i < 0 ? null : url.substring(i);
  }
}
