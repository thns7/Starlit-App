import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:starlitfilms/config.dart';
import 'package:starlitfilms/models/movie.dart';

/// Cliente da API do TMDB (https://developer.themoviedb.org).
class TmdbService {
  TmdbService._();
  static final TmdbService instance = TmdbService._();

  static const _base = 'api.themoviedb.org';
  static const _language = 'pt-BR';
  static const _region = 'BR';

  final Map<String, _CacheEntry> _cache = {};

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? params]) async {
    final uri = Uri.https(_base, '/3$path', {
      'language': _language,
      ...?params,
    });
    final key = uri.toString();
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.at).inMinutes < 30) {
      return cached.data;
    }

    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer ${AppConfig.tmdbToken}',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw 'Não foi possível carregar os filmes (TMDB ${response.statusCode}).';
    }
    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    _cache[key] = _CacheEntry(data);
    return data;
  }

  Future<List<TmdbMovie>> _list(String path,
      [Map<String, String>? params]) async {
    final data = await _get(path, params);
    final results =
        (data['results'] as List? ?? const []).cast<Map<String, dynamic>>();
    return results.map(TmdbMovie.fromJson).toList();
  }

  /// Em cartaz nos cinemas do Brasil.
  Future<List<TmdbMovie>> nowPlaying() =>
      _list('/movie/now_playing', {'region': _region});

  /// Próximos lançamentos no Brasil.
  Future<List<TmdbMovie>> upcoming() async {
    final movies = await _list('/movie/upcoming', {'region': _region});
    final today = DateTime.now();
    final future = movies
        .where((m) =>
            m.releaseDate == null ||
            !m.releaseDate!
                .isBefore(DateTime(today.year, today.month, today.day)))
        .toList()
      ..sort((a, b) => (a.releaseDate ?? DateTime(9999))
          .compareTo(b.releaseDate ?? DateTime(9999)));
    return future.isNotEmpty ? future : movies;
  }

  /// Em alta na semana.
  Future<List<TmdbMovie>> trending() => _list('/trending/movie/week');

  Future<List<TmdbMovie>> search(String query) {
    final q = query.trim();
    if (q.isEmpty) return Future.value(const []);
    return _list('/search/movie', {'query': q, 'include_adult': 'false'});
  }

  Future<TmdbMovie> details(int tmdbId) async {
    return TmdbMovie.fromJson(await _get('/movie/$tmdbId'));
  }
}

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime at = DateTime.now();
  _CacheEntry(this.data);
}
