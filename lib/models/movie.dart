class Movie {
  final int id;
  final String title;
  final int? year;
  final String? posterUrl;

  const Movie({
    required this.id,
    required this.title,
    this.year,
    this.posterUrl,
  });

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
    );
  }
}
