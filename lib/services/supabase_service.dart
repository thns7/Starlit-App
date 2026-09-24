import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:starlitfilms/models/message.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/models/profile.dart';
import 'package:starlitfilms/models/review.dart';

/// Todas as consultas ao Supabase ficam aqui.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  /// Só para testes: cliente e usuário alternativos (ex.: banco local).
  @visibleForTesting
  static SupabaseClient? debugClient;
  @visibleForTesting
  static String? debugUserId;

  SupabaseClient get _db => debugClient ?? Supabase.instance.client;

  String? get currentUserId => debugUserId ?? _db.auth.currentUser?.id;

  static const _profileFields = 'id, username, name, bio, avatar_url';
  // "!reviews_user_id_fkey": a review se liga a profiles pelo autor e também
  // pelas curtidas (review_likes); sem isso o PostgREST não sabe qual usar.
  static final _reviewSelect = '''
    id, content, rating, is_public, created_at,
    author:profiles!reviews_user_id_fkey($_profileFields),
    movie:movies(${Movie.selectFields}),
    likes:review_likes(count),
    comments(count),
    my_like:review_likes(user_id)
  ''';

  // ===================== Perfis =====================

  Future<Profile?> fetchProfile(String userId) async {
    final data = await _db
        .from('profiles')
        .select(_profileFields)
        .eq('id', userId)
        .maybeSingle();
    return data == null ? null : Profile.fromJson(data);
  }

  Future<bool> isUsernameAvailable(String username) async {
    final result = await _db.rpc(
      'username_available',
      params: {'p_username': username},
    );
    return result == true;
  }

  Future<Profile> updateProfile({
    required String name,
    required String username,
    required String bio,
    String? avatarUrl,
  }) async {
    final data = await _db
        .from('profiles')
        .update({
          'name': name,
          'username': username.toLowerCase(),
          'bio': bio,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        })
        .eq('id', currentUserId!)
        .select(_profileFields)
        .single();
    return Profile.fromJson(data);
  }

  /// Envia a foto para o bucket `avatars` e devolve a URL pública.
  Future<String> uploadAvatar(Uint8List bytes, String fileExtension) async {
    final ext = fileExtension.toLowerCase().replaceAll('.', '');
    final path =
        '$currentUserId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
            upsert: true,
          ),
        );
    return _db.storage.from('avatars').getPublicUrl(path);
  }

  Future<List<Profile>> searchProfiles(String query) async {
    final q = query.trim().replaceAll(RegExp(r'[%,()]'), '');
    var request = _db.from('profiles').select(_profileFields);
    if (q.isNotEmpty) {
      request = request.or('username.ilike.%$q%,name.ilike.%$q%');
    }
    final data = await request.neq('id', currentUserId!).limit(30);
    return data.map(Profile.fromJson).toList();
  }

  // ===================== Filmes =====================

  Future<List<Movie>> fetchMovies() async {
    final data =
        await _db.from('movies').select(Movie.selectFields).order('title');
    return data.map(Movie.fromJson).toList();
  }

  Future<Movie> addMovie({
    required String title,
    int? year,
    String? posterUrl,
  }) async {
    final data = await _db
        .from('movies')
        .insert({
          'title': title.trim(),
          'year': year,
          'poster_url': (posterUrl == null || posterUrl.trim().isEmpty)
              ? null
              : posterUrl.trim(),
        })
        .select(Movie.selectFields)
        .single();
    return Movie.fromJson(data);
  }

  /// Grava (ou atualiza) um filme do TMDB no banco e devolve o registro local.
  Future<Movie> ensureTmdbMovie(TmdbMovie movie) async {
    final id = await _db.rpc('ensure_tmdb_movie', params: {
      'p_tmdb_id': movie.tmdbId,
      'p_title': movie.title,
      'p_release_date': movie.releaseDate?.toIso8601String().substring(0, 10),
      'p_poster_url': movie.posterUrl,
      'p_backdrop_url': movie.backdropUrl,
      'p_overview': movie.overview.isEmpty ? null : movie.overview,
    });
    return Movie(
      id: id as int,
      title: movie.title,
      year: movie.year,
      posterUrl: movie.posterUrl,
      tmdbId: movie.tmdbId,
      overview: movie.overview,
      backdropUrl: movie.backdropUrl,
    );
  }

  Future<Movie?> findMovieByTmdbId(int tmdbId) async {
    final data = await _db
        .from('movies')
        .select(Movie.selectFields)
        .eq('tmdb_id', tmdbId)
        .maybeSingle();
    return data == null ? null : Movie.fromJson(data);
  }

  Future<List<Movie>> searchLocalMovies(String query) async {
    final q = query.trim().replaceAll('%', '');
    var request = _db.from('movies').select(Movie.selectFields);
    if (q.isNotEmpty) request = request.ilike('title', '%$q%');
    final data = await request.order('title').limit(30);
    return data.map(Movie.fromJson).toList();
  }

  // ===================== Reviews =====================

  Future<List<Review>> fetchMovieReviews(int movieId) async {
    final data = await _db
        .from('reviews')
        .select(_reviewSelect)
        .eq('my_like.user_id', currentUserId!)
        .eq('movie_id', movieId)
        .order('created_at', ascending: false);
    return data
        .map((j) => Review.fromJson(j, currentUserId: currentUserId))
        .toList();
  }

  Future<List<Review>> fetchFeed({String? search}) async {
    var request = _db
        .from('reviews')
        .select(_reviewSelect)
        .eq('my_like.user_id', currentUserId!);
    final q = search?.trim() ?? '';
    if (q.isNotEmpty) {
      final movies = await _db
          .from('movies')
          .select('id')
          .ilike('title', '%${q.replaceAll('%', '')}%');
      final ids = movies.map((m) => m['id'] as int).toList();
      if (ids.isEmpty) return [];
      request = request.inFilter('movie_id', ids);
    }
    final data = await request.order('created_at', ascending: false).limit(50);
    return data
        .map((j) => Review.fromJson(j, currentUserId: currentUserId))
        .toList();
  }

  Future<Review?> fetchReview(int reviewId) async {
    final data = await _db
        .from('reviews')
        .select(_reviewSelect)
        .eq('my_like.user_id', currentUserId!)
        .eq('id', reviewId)
        .maybeSingle();
    return data == null
        ? null
        : Review.fromJson(data, currentUserId: currentUserId);
  }

  Future<List<Review>> fetchUserReviews(String userId) async {
    final data = await _db
        .from('reviews')
        .select(_reviewSelect)
        .eq('my_like.user_id', currentUserId!)
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return data
        .map((j) => Review.fromJson(j, currentUserId: currentUserId))
        .toList();
  }

  Future<void> createReview({
    required int movieId,
    required String content,
    required int rating,
    required bool isPublic,
  }) async {
    await _db.from('reviews').insert({
      'movie_id': movieId,
      'content': content.trim(),
      'rating': rating,
      'is_public': isPublic,
    });
  }

  Future<void> deleteReview(int reviewId) async {
    await _db.from('reviews').delete().eq('id', reviewId);
  }

  Future<void> setLike(int reviewId, bool liked) async {
    if (liked) {
      await _db.from('review_likes').upsert(
        {'review_id': reviewId, 'user_id': currentUserId},
        ignoreDuplicates: true,
      );
    } else {
      await _db
          .from('review_likes')
          .delete()
          .eq('review_id', reviewId)
          .eq('user_id', currentUserId!);
    }
  }

  /// Total de curtidas recebidas nas reviews de um usuário.
  Future<int> countLikesReceived(String userId) async {
    final data = await _db
        .from('review_likes')
        .select('review_id, reviews!inner(user_id)')
        .eq('reviews.user_id', userId)
        .count(CountOption.exact);
    return data.count;
  }

  // ===================== Comentários =====================

  static const _commentSelect = '''
    id, content, created_at, review_id,
    author:profiles($_profileFields),
    review:reviews(movie:movies(title))
  ''';

  Future<List<Comment>> fetchComments(int reviewId) async {
    final data = await _db
        .from('comments')
        .select(_commentSelect)
        .eq('review_id', reviewId)
        .order('created_at');
    return data.map(Comment.fromJson).toList();
  }

  Future<List<Comment>> fetchUserComments(String userId) async {
    final data = await _db
        .from('comments')
        .select(_commentSelect)
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return data.map(Comment.fromJson).toList();
  }

  Future<void> addComment(int reviewId, String content) async {
    await _db
        .from('comments')
        .insert({'review_id': reviewId, 'content': content.trim()});
  }

  Future<void> deleteComment(int commentId) async {
    await _db.from('comments').delete().eq('id', commentId);
  }

  // ===================== Amizades =====================

  Future<List<Map<String, dynamic>>> _friendshipRows() async {
    final me = currentUserId!;
    return await _db.from('friendships').select('''
          requester_id, addressee_id, status,
          requester:profiles!friendships_requester_id_fkey($_profileFields),
          addressee:profiles!friendships_addressee_id_fkey($_profileFields)
        ''').or('requester_id.eq.$me,addressee_id.eq.$me');
  }

  /// Amigos aceitos.
  Future<List<Profile>> fetchFriends() async {
    final me = currentUserId!;
    final rows = await _friendshipRows();
    return rows.where((r) => r['status'] == 'accepted').map((r) {
      final other = r['requester_id'] == me ? r['addressee'] : r['requester'];
      return Profile.fromJson(other as Map<String, dynamic>);
    }).toList();
  }

  /// Pedidos recebidos aguardando resposta.
  Future<List<Profile>> fetchIncomingRequests() async {
    final me = currentUserId!;
    final rows = await _friendshipRows();
    return rows
        .where((r) => r['status'] == 'pending' && r['addressee_id'] == me)
        .map((r) => Profile.fromJson(r['requester'] as Map<String, dynamic>))
        .toList();
  }

  /// IDs de usuários com quem já existe amizade ou pedido (em qualquer direção).
  Future<Map<String, String>> fetchRelationshipStatus() async {
    final me = currentUserId!;
    final rows = await _friendshipRows();
    final result = <String, String>{};
    for (final r in rows) {
      final isOutgoing = r['requester_id'] == me;
      final otherId =
          (isOutgoing ? r['addressee_id'] : r['requester_id']) as String;
      result[otherId] = r['status'] == 'accepted'
          ? 'accepted'
          : (isOutgoing ? 'sent' : 'received');
    }
    return result;
  }

  Future<void> sendFriendRequest(String userId) async {
    await _db.from('friendships').insert({'addressee_id': userId});
  }

  Future<void> acceptFriendRequest(String requesterId) async {
    await _db
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('requester_id', requesterId)
        .eq('addressee_id', currentUserId!);
  }

  /// Recusa pedido, cancela pedido enviado ou desfaz amizade.
  Future<void> removeFriendship(String otherUserId) async {
    final me = currentUserId!;
    await _db.from('friendships').delete().or(
          'and(requester_id.eq.$me,addressee_id.eq.$otherUserId),'
          'and(requester_id.eq.$otherUserId,addressee_id.eq.$me)',
        );
  }

  // ===================== Mensagens =====================

  /// Últimas mensagens trocadas com [otherUserId], da mais antiga para a mais nova.
  Future<List<Message>> fetchConversation(String otherUserId, {int limit = 200}) async {
    final me = currentUserId!;
    final data = await _db
        .from('messages')
        .select()
        .or('and(sender_id.eq.$me,receiver_id.eq.$otherUserId),'
            'and(sender_id.eq.$otherUserId,receiver_id.eq.$me)')
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return data.map(Message.fromJson).toList().reversed.toList();
  }

  /// Canal em tempo real do chat: mensagens novas do amigo e "visto" nas minhas.
  RealtimeChannel subscribeConversation(
    String otherUserId, {
    required void Function(Message message) onChange,
    required void Function(bool connected) onStatus,
  }) {
    final me = currentUserId!;
    return _db
        .channel('chat:$me:$otherUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'receiver_id', value: me),
          callback: (p) {
            final m = Message.fromJson(p.newRecord);
            if (m.senderId == otherUserId) onChange(m);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'sender_id', value: me),
          callback: (p) {
            final m = Message.fromJson(p.newRecord);
            if (m.receiverId == otherUserId) onChange(m);
          },
        )
        .subscribe((status, [error]) {
      onStatus(status == RealtimeSubscribeStatus.subscribed);
    });
  }

  Future<void> removeChannel(RealtimeChannel channel) => _db.removeChannel(channel);

  Future<List<Conversation>> listConversations() async {
    final data = await _db.rpc('list_conversations') as List;
    return data
        .map((j) => Conversation.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
  }

  Future<void> markConversationRead(String friendId) async {
    await _db.rpc('mark_conversation_read', params: {'p_friend': friendId});
  }

  /// Total de mensagens recebidas ainda não lidas.
  Future<int> countUnreadMessages() async {
    final res = await _db
        .from('messages')
        .select('id')
        .eq('receiver_id', currentUserId!)
        .isFilter('read_at', null)
        .count(CountOption.exact);
    return res.count;
  }

  Future<Message> sendMessage(String receiverId, String content) async {
    final data = await _db
        .from('messages')
        .insert({'receiver_id': receiverId, 'content': content.trim()})
        .select()
        .single();
    return Message.fromJson(data);
  }
}
