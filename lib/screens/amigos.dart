import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/message.dart';
import 'package:starlitfilms/models/profile.dart';
import 'package:starlitfilms/screens/biblioteca.dart';
import 'package:starlitfilms/screens/conversas.dart';
import 'package:starlitfilms/services/notification_center.dart';
import 'package:starlitfilms/services/supabase_service.dart';
import 'package:starlitfilms/theme/tokens.dart';


class AmigosPage extends StatefulWidget {
  const AmigosPage({super.key});

  @override
  State<AmigosPage> createState() => _AmigosPageState();
}

class _AmigosPageState extends State<AmigosPage> {
  final _service = SupabaseService.instance;
  List<Profile> _amigos = [];
  List<Profile> _pedidos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _tab = 0; // 0 = conversas, 1 = amigos
  List<Conversation> _conversas = [];
  int _lastRevision = -1;

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait<Object>([
        _service.fetchFriends(),
        _service.fetchIncomingRequests(),
        // Se a migração do chat ainda não foi aplicada, a lista de amigos
        // continua funcionando.
        _service.listConversations().catchError((Object e) {
          debugPrint('Conversas indisponíveis: $e');
          return <Conversation>[];
        }),
      ]);
      if (!mounted) return;
      setState(() {
        _amigos = (results[0] as List<Profile>)
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        _pedidos = results[1] as List<Profile>;
        _conversas = results[2] as List<Conversation>;
      });
      if (mounted) context.read<NotificationCenter>().refreshCounts();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      showStarlitToast(context, success, icon: Icons.people_alt_rounded);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: SC.danger),
      );
    }
  }

  Future<void> _openChat(Profile amigo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(amigo: amigo)),
    );
    _load();
  }

  Future<void> _openProfile(Profile profile) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BibliotecaPage(userId: profile.id)),
    );
    _load();
  }

  void _showFriendOptions(Profile amigo) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_rounded),
              title: const Text('Conversar'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openChat(amigo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Ver perfil'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openProfile(amigo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_rounded, color: SC.danger),
              title: const Text('Desfazer amizade', style: TextStyle(color: SC.danger)),
              onTap: () {
                Navigator.pop(sheetContext);
                _run(() => _service.removeFriendship(amigo.id), 'Amizade desfeita.');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BuscarUsuariosPage()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // Evento em tempo real (pedido, mensagem, aceite): recarrega a lista.
    final revision = context.watch<NotificationCenter>().revision;
    if (revision != _lastRevision) {
      final first = _lastRevision == -1;
      _lastRevision = revision;
      if (!first) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    return Scaffold(
      backgroundColor: SC.bg,
      body: SkyBackground(
        starCount: 40,
        child: RefreshIndicator(
          onRefresh: _load,
          color: SC.star,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(SSpace.page, 16, SSpace.page - 4, 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Amigos',
                              style: TextStyle(
                                  fontSize: 26,
                                  color: SC.text,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5)),
                        ),
                        Pressable(
                          onTap: _openSearch,
                          semanticLabel: 'Encontrar pessoas',
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              gradient: SC.buttonGradient,
                              borderRadius: BorderRadius.circular(SRadius.md),
                              boxShadow: SShadow.glowButton,
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.person_add_alt_1_rounded,
                                    color: Colors.white, size: 19),
                                SizedBox(width: 6),
                                Text('Encontrar',
                                    style: TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(SSpace.page, 14, SSpace.page, 0),
                  child: _Segmented(
                    index: _tab,
                    labels: const ['Conversas', 'Amigos'],
                    badges: [
                      _conversas.fold<int>(0, (a, c) => a + c.unread),
                      _pedidos.length,
                    ],
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
              ),
              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(SSpace.page, 16, SSpace.page, 0),
                  sliver: SliverList.separated(
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, __) => const Skeleton(height: 72, radius: SRadius.lg),
                  ),
                )
              else if (_tab == 0) ...[
                if (_conversas.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.forum_rounded,
                      title: 'Nenhuma conversa ainda',
                      message: _amigos.isEmpty
                          ? 'Adicione amigos para começar a conversar.'
                          : 'Escolha um amigo e mande um oi.',
                      actionLabel: _amigos.isEmpty ? 'Encontrar pessoas' : null,
                      onAction: _amigos.isEmpty ? _openSearch : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 10),
                    sliver: SliverList.builder(
                      itemCount: _conversas.length,
                      itemBuilder: (context, i) => Entrance(
                        key: ValueKey('conv${_conversas[i].friend.id}'),
                        index: i,
                        child: _ConversationRow(
                          conversation: _conversas[i],
                          myId: _service.currentUserId,
                          onTap: () => _openChat(_conversas[i].friend),
                        ),
                      ),
                    ),
                  ),
              ] else ...[
                if (_error != null)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Não foi possível carregar',
                      message: _error,
                      actionLabel: 'Tentar novamente',
                      onAction: _load,
                    ),
                  ),
                if (_pedidos.isNotEmpty) ...[
                  _sectionLabel('Pedidos de amizade', _pedidos.length),
                  SliverList.builder(
                    itemCount: _pedidos.length,
                    itemBuilder: (context, i) {
                      final p = _pedidos[i];
                      return Entrance(
                        key: ValueKey('p${p.id}'),
                        index: i,
                        child: _PersonRow(
                          profile: p,
                          onTap: () => _openProfile(p),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filled(
                                tooltip: 'Aceitar',
                                style: IconButton.styleFrom(backgroundColor: SC.primary),
                                icon: const Icon(Icons.check_rounded, color: Colors.white),
                                onPressed: () => _run(() => _service.acceptFriendRequest(p.id),
                                    'Agora vocês são amigos'),
                              ),
                              IconButton(
                                tooltip: 'Recusar',
                                icon: const Icon(Icons.close_rounded, color: SC.textMuted),
                                onPressed: () => _run(
                                    () => _service.removeFriendship(p.id), 'Pedido recusado'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (_amigos.isNotEmpty) _sectionLabel('Seus amigos', _amigos.length),
                if (_amigos.isEmpty && _error == null)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.people_alt_rounded,
                      title: 'Seu círculo ainda está vazio',
                      message:
                          'Encontre pessoas pelo nome ou @ para trocar reviews e conversar.',
                      actionLabel: 'Encontrar pessoas',
                      onAction: _openSearch,
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: _amigos.length,
                    itemBuilder: (context, i) {
                      final amigo = _amigos[i];
                      return Entrance(
                        key: ValueKey('a${amigo.id}'),
                        index: i,
                        child: _PersonRow(
                          profile: amigo,
                          onTap: () => _openChat(amigo),
                          onLongPress: () => _showFriendOptions(amigo),
                          trailing: IconButton(
                            tooltip: 'Opções',
                            icon: const Icon(Icons.more_horiz_rounded, color: SC.textMuted),
                            onPressed: () => _showFriendOptions(amigo),
                          ),
                        ),
                      );
                    },
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(SSpace.page, 22, SSpace.page, 8),
        child: Row(
          children: [
            Text(text,
                style: const TextStyle(
                    color: SC.text, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: SC.surfaceHigher,
                borderRadius: BorderRadius.circular(SRadius.pill),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: SC.starSoft, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Controle segmentado com indicador deslizante e contadores.
class _Segmented extends StatelessWidget {
  final int index;
  final List<String> labels;
  final List<int> badges;
  final ValueChanged<int> onChanged;

  const _Segmented({
    required this.index,
    required this.labels,
    required this.badges,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(SRadius.md),
        border: Border.all(color: SC.outline.withValues(alpha: 0.35)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: index == 0 ? Alignment.centerLeft : Alignment.centerRight,
            duration: SMotion.of(context, const Duration(milliseconds: 260)),
            curve: SMotion.easeInOut,
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: SC.buttonGradient,
                  borderRadius: BorderRadius.circular(SRadius.sm),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: SMotion.of(context, SMotion.quick),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: i == index ? Colors.white : SC.textFaint,
                            ),
                            child: Text(labels[i]),
                          ),
                          if (badges[i] > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5A6E),
                                borderRadius: BorderRadius.circular(SRadius.pill),
                              ),
                              child: Text('${badges[i]}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _shortTime(DateTime? d) {
  if (d == null) return '';
  final t = d.toLocal();
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  if (t.year == now.year && t.month == now.month && t.day == now.day) {
    return '${two(t.hour)}:${two(t.minute)}';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (t.year == yesterday.year && t.month == yesterday.month && t.day == yesterday.day) {
    return 'Ontem';
  }
  return '${two(t.day)}/${two(t.month)}';
}

/// Linha da lista de conversas: último texto, horário e não lidas.
class _ConversationRow extends StatelessWidget {
  final Conversation conversation;
  final String? myId;
  final VoidCallback onTap;

  const _ConversationRow({required this.conversation, required this.myId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final mine = c.lastSenderId != null && c.lastSenderId == myId;
    final unread = c.unread > 0;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: SSpace.page, vertical: 5),
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: unread ? SC.surfaceHigh : SC.surface,
          borderRadius: BorderRadius.circular(SRadius.lg),
          border: Border.all(
              color: unread ? SC.star.withValues(alpha: 0.5) : SC.outline.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            UserAvatar.of(c.friend, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.friend.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: SC.text,
                          fontSize: 15.5,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (mine) ...[
                        Icon(
                          c.lastReadAt != null ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 15,
                          color: c.lastReadAt != null ? SC.starSoft : SC.textFaint,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          c.lastContent ?? 'Toque para começar a conversa',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread ? SC.text : SC.textFaint,
                            fontSize: 13.5,
                            fontStyle: c.lastContent == null ? FontStyle.italic : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_shortTime(c.lastAt),
                    style: TextStyle(
                        color: unread ? SC.starSoft : SC.textFaint,
                        fontSize: 12,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400)),
                const SizedBox(height: 6),
                AnimatedScale(
                  scale: unread ? 1 : 0,
                  duration: SMotion.of(context, const Duration(milliseconds: 220)),
                  curve: SMotion.easeOut,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: SC.buttonGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${c.unread}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha de pessoa: avatar, nome, @ e ação à direita.
class _PersonRow extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const _PersonRow({
    required this.profile,
    required this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: 0.98,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: SSpace.page, vertical: 5),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: SC.surface,
          borderRadius: BorderRadius.circular(SRadius.lg),
          border: Border.all(color: SC.outline.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            UserAvatar.of(profile, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: SC.text, fontSize: 15.5, fontWeight: FontWeight.w600)),
                  Text('@${profile.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: SC.textFaint, fontSize: 13)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Busca de usuários por nome ou @username, com botão de adicionar.
class BuscarUsuariosPage extends StatefulWidget {
  const BuscarUsuariosPage({super.key});

  @override
  State<BuscarUsuariosPage> createState() => _BuscarUsuariosPageState();
}

class _BuscarUsuariosPageState extends State<BuscarUsuariosPage> {
  final _service = SupabaseService.instance;
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Profile> _results = [];
  Map<String, String> _status = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.searchProfiles(_controller.text.replaceAll('@', '')),
        _service.fetchRelationshipStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _results = results[0] as List<Profile>;
        _status = results[1] as Map<String, String>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: SC.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(Profile p) async {
    try {
      switch (_status[p.id]) {
        case null:
          await _service.sendFriendRequest(p.id);
          if (mounted) showStarlitToast(context, 'Pedido enviado para @${p.username}');
          break;
        case 'received':
          await _service.acceptFriendRequest(p.id);
          if (mounted) {
            showStarlitToast(context, 'Agora você e @${p.username} são amigos',
                icon: Icons.people_alt_rounded);
          }
          break;
        case 'sent':
          await _service.removeFriendship(p.id);
          break;
        default:
          return;
      }
      await _search();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: SC.danger),
        );
      }
    }
  }

  Widget _actionButton(Profile p) {
    final status = _status[p.id];
    final (label, filled) = switch (status) {
      'accepted' => ('Amigos', false),
      'sent' => ('Enviado', false),
      'received' => ('Aceitar', true),
      _ => ('Adicionar', true),
    };
    return AnimatedSwitcher(
      duration: SMotion.of(context, SMotion.quick),
      child: filled
          ? FilledButton(
              key: ValueKey(label),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () => _action(p),
              child: Text(label),
            )
          : OutlinedButton(
              key: ValueKey(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: SC.textMuted,
                side: BorderSide(color: SC.outline.withValues(alpha: 0.7)),
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SRadius.md)),
              ),
              onPressed: status == 'accepted' ? null : () => _action(p),
              child: Text(status == 'sent' ? 'Cancelar' : label),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SC.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: SSpace.page),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), _search);
            },
            style: const TextStyle(color: SC.text),
            decoration: const InputDecoration(
              hintText: 'Nome ou @username',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
      ),
      body: _loading && _results.isEmpty
          ? ListView.separated(
              padding: const EdgeInsets.all(SSpace.page),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, __) => const Skeleton(height: 68, radius: SRadius.lg),
            )
          : _results.isEmpty
              ? const Center(
                  child: EmptyState(
                    icon: Icons.person_search_rounded,
                    title: 'Ninguém encontrado',
                    message: 'Confira a grafia ou tente pelo @username.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final p = _results[index];
                    return Entrance(
                      key: ValueKey(p.id),
                      index: index,
                      child: _PersonRow(
                        profile: p,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BibliotecaPage(userId: p.id)),
                        ).then((_) => _search()),
                        trailing: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _actionButton(p),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
