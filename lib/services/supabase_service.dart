import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:starlitfilms/models/message.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/models/profile.dart';
import 'package:starlitfilms/models/review.dart';

/// Todas as consultas ao Supabase ficam aqui.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _db => Supabase.instance.client;

  String? get currentUserId => _db.auth.currentUser?.id;

  static const _profileFields = 'id, username, name, bio, avatar_url';
  static const _reviewSelect = '''
    id, content, rating, is_public, created_at,
    author:profiles($_profileFields),
    movie:movies(id, title, year, poster_url),
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
    final data = await _db
        .from('movies')
        .select('id, title, year, poster_url')
        .order('title');
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
          'poster_url':
              (posterUrl == null || posterUrl.trim().isEmpty) ? null : posterUrl.trim(),
        })
        .select('id, title, year, poster_url')
        .single();
    return Movie.fromJson(data);
  }

  // ===================== Reviews =====================

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
    return await _db
        .from('friendships')
        .select('''
          requester_id, addressee_id, status,
          requester:profiles!friendships_requester_id_fkey($_profileFields),
          addressee:profiles!friendships_addressee_id_fkey($_profileFields)
        ''')
        .or('requester_id.eq.$me,addressee_id.eq.$me');
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

  /// Mensagens entre o usuário atual e [otherUserId], em tempo real.
  /// O RLS garante que só chegam mensagens das quais o usuário participa.
  Stream<List<Message>> conversationStream(String otherUserId) {
    final me = currentUserId!;
    return _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .inFilter('sender_id', [me, otherUserId])
        .order('created_at')
        .map((rows) => rows
            .map(Message.fromJson)
            .where((m) =>
                (m.senderId == me && m.receiverId == otherUserId) ||
                (m.senderId == otherUserId && m.receiverId == me))
            .toList());
  }

  Future<void> sendMessage(String receiverId, String content) async {
    await _db
        .from('messages')
        .insert({'receiver_id': receiverId, 'content': content.trim()});
  }
}
