import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:starlitfilms/components/banner.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/models/profile.dart';
import 'package:starlitfilms/screens/biblioteca.dart';
import 'package:starlitfilms/screens/conversas.dart';
import 'package:starlitfilms/services/supabase_service.dart';

/// Navegador global: permite abrir telas e mostrar banners a partir de
/// eventos em tempo real, de qualquer lugar do app.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Escuta em tempo real pedidos de amizade, aceites e mensagens novas do
/// usuário logado; mostra banners e mantém os contadores das abas.
class NotificationCenter extends ChangeNotifier {
  final _service = SupabaseService.instance;
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _channel;
  String? _userId;

  int pendingRequests = 0;
  int unreadMessages = 0;

  /// Amigo cuja conversa está aberta agora (não avisar mensagens dele).
  String? activeChatFriendId;

  /// Incrementa a cada evento: telas de lista usam para recarregar.
  int revision = 0;

  int get badge => pendingRequests + unreadMessages;

  NotificationCenter() {
    final auth = Supabase.instance.client.auth;
    _authSub = auth.onAuthStateChange.listen((s) {
      final id = s.session?.user.id;
      if (id == null) {
        _stop();
      } else if (id != _userId) {
        _start(id);
      }
    });
    final current = auth.currentUser?.id;
    if (current != null) _start(current);
  }

  SupabaseClient get _db => Supabase.instance.client;

  void _start(String userId) {
    _stop();
    _userId = userId;
    refreshCounts();

    _channel = _db
        .channel('inbox:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friendships',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'addressee_id', value: userId),
          callback: (p) => _onFriendRequest(p.newRecord['requester_id'] as String?),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'friendships',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'requester_id', value: userId),
          callback: (p) {
            if (p.newRecord['status'] == 'accepted') {
              _onRequestAccepted(p.newRecord['addressee_id'] as String?);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'receiver_id', value: userId),
          callback: (p) => _onMessage(p.newRecord),
        )
        .subscribe();
  }

  void _stop() {
    final ch = _channel;
    _channel = null;
    if (ch != null) _db.removeChannel(ch);
    _userId = null;
    pendingRequests = 0;
    unreadMessages = 0;
    activeChatFriendId = null;
    notifyListeners();
  }

  Future<void> refreshCounts() async {
    if (_userId == null) return;
    try {
      final results = await Future.wait([
        _service.fetchIncomingRequests(),
        _service.countUnreadMessages(),
      ]);
      pendingRequests = (results[0] as List).length;
      unreadMessages = results[1] as int;
      revision++;
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao atualizar avisos: $e');
    }
  }

  OverlayState? get _overlay => appNavigatorKey.currentState?.overlay;
  BuildContext? get _ctx => appNavigatorKey.currentContext;

  void _open(Widget page) {
    appNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _onFriendRequest(String? requesterId) async {
    if (requesterId == null) return;
    await refreshCounts();
    final Profile? p = await _service.fetchProfile(requesterId).catchError((_) => null);
    final overlay = _overlay;
    if (p == null || overlay == null) return;
    showStarlitBanner(
      overlay,
      title: '${p.displayName} quer ser seu amigo',
      body: '@${p.username} te enviou um pedido de amizade',
      avatarUrl: p.avatarUrl,
      icon: Icons.person_add_alt_1_rounded,
      onTap: () => _open(BibliotecaPage(userId: p.id)),
      actions: [
        BannerAction('Ver perfil', () => _open(BibliotecaPage(userId: p.id))),
        BannerAction('Aceitar', () async {
          try {
            await _service.acceptFriendRequest(p.id);
            final ctx = _ctx;
            if (ctx != null && ctx.mounted) {
              showStarlitToast(ctx, 'Agora você e @${p.username} são amigos',
                  icon: Icons.people_alt_rounded);
            }
            refreshCounts();
          } catch (e) {
            debugPrint('Erro ao aceitar: $e');
          }
        }, primary: true),
      ],
    );
  }

  Future<void> _onRequestAccepted(String? friendId) async {
    if (friendId == null) return;
    revision++;
    notifyListeners();
    final Profile? p = await _service.fetchProfile(friendId).catchError((_) => null);
    final overlay = _overlay;
    if (p == null || overlay == null) return;
    showStarlitBanner(
      overlay,
      title: '${p.displayName} aceitou seu pedido',
      body: 'Agora vocês podem conversar e ver as reviews só para amigos.',
      avatarUrl: p.avatarUrl,
      icon: Icons.people_alt_rounded,
      onTap: () => _open(ChatPage(amigo: p)),
      actions: [BannerAction('Conversar', () => _open(ChatPage(amigo: p)), primary: true)],
    );
  }

  Future<void> _onMessage(Map<String, dynamic> record) async {
    final senderId = record['sender_id'] as String?;
    if (senderId == null) return;
    if (senderId == activeChatFriendId) {
      revision++;
      notifyListeners();
      return;
    }
    await refreshCounts();
    final Profile? p = await _service.fetchProfile(senderId).catchError((_) => null);
    final overlay = _overlay;
    if (p == null || overlay == null) return;
    showStarlitBanner(
      overlay,
      title: p.displayName,
      body: record['content'] as String? ?? 'Nova mensagem',
      avatarUrl: p.avatarUrl,
      icon: Icons.chat_bubble_rounded,
      onTap: () => _open(ChatPage(amigo: p)),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _stop();
    super.dispose();
  }
}
