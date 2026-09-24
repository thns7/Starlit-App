import 'dart:async';
import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/message.dart';
import 'package:starlitfilms/models/profile.dart';
import 'package:starlitfilms/services/notification_center.dart';
import 'package:starlitfilms/services/supabase_service.dart';
import 'package:starlitfilms/theme/tokens.dart';

/// Chat em tempo real com um amigo (Supabase Realtime).
class ChatPage extends StatefulWidget {
  final Profile amigo;

  const ChatPage({super.key, required this.amigo});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _service = SupabaseService.instance;
  final _messageController = TextEditingController();
  List<Message>? _messages;
  Object? _loadError;
  RealtimeChannel? _chatChannel;
  Timer? _poll;
  bool _isEmojiVisible = false;
  bool _sending = false;

  NotificationCenter? _center;
  RealtimeChannel? _typingChannel;
  Timer? _typingOff;
  DateTime _lastTypingSent = DateTime(0);
  bool _friendTyping = false;
  int _lastMarkedId = 0;

  Future<void> _fetch() async {
    try {
      final list = await _service.fetchConversation(widget.amigo.id);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loadError = null;
      });
    } catch (e) {
      if (mounted && _messages == null) setState(() => _loadError = e);
    }
  }

  /// Insere ou atualiza uma mensagem mantendo a ordem cronológica.
  void _upsert(Message m) {
    if (!mounted) return;
    setState(() {
      final list = [...?_messages];
      final i = list.indexWhere((x) => x.id == m.id);
      if (i >= 0) {
        list[i] = m;
      } else {
        list.add(m);
        list.sort((a, b) {
          final c = a.createdAt.compareTo(b.createdAt);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
      }
      _messages = list;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetch();
    if (_service.currentUserId != null) {
      _chatChannel = _service.subscribeConversation(
        widget.amigo.id,
        onChange: _upsert,
        onStatus: (connected) {
          // Sem tempo real (rede instável): busca de novo a cada 5s.
          if (connected) {
            _poll?.cancel();
            _poll = null;
            _fetch();
          } else {
            _poll ??= Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
          }
        },
      );
    }
    _messageController.addListener(_onTextChanged);
    final me = _service.currentUserId;
    if (me != null) {
      // Canal só da dupla (ids em ordem) para o aviso "digitando…".
      final ids = [me, widget.amigo.id]..sort();
      _typingChannel = Supabase.instance.client
          .channel('typing:${ids.join(':')}')
          .onBroadcast(
            event: 'typing',
            callback: (payload) {
              if (payload['user'] != widget.amigo.id || !mounted) return;
              setState(() => _friendTyping = true);
              _typingOff?.cancel();
              _typingOff = Timer(const Duration(seconds: 3), () {
                if (mounted) setState(() => _friendTyping = false);
              });
            },
          )
          .subscribe();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _center ??= context.read<NotificationCenter>()..activeChatFriendId = widget.amigo.id;
  }

  @override
  void dispose() {
    if (_center?.activeChatFriendId == widget.amigo.id) {
      _center?.activeChatFriendId = null;
    }
    _center?.refreshCounts();
    _typingOff?.cancel();
    _poll?.cancel();
    final chat = _chatChannel;
    if (chat != null) _service.removeChannel(chat);
    final ch = _typingChannel;
    if (ch != null) Supabase.instance.client.removeChannel(ch);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final ch = _typingChannel;
    if (ch == null || _messageController.text.trim().isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(seconds: 2)) return;
    _lastTypingSent = now;
    ch.sendBroadcastMessage(event: 'typing', payload: {'user': _service.currentUserId});
  }

  /// Marca como lidas as mensagens do amigo que chegaram (uma vez por lote).
  void _markRead(List<Message> messages, String? me) {
    final lastIncoming = messages.lastWhere(
      (m) => m.senderId == widget.amigo.id && m.readAt == null,
      orElse: () => Message(
          id: 0, senderId: '', receiverId: '', content: '', createdAt: DateTime(0)),
    );
    if (lastIncoming.id == 0 || lastIncoming.id <= _lastMarkedId) return;
    _lastMarkedId = lastIncoming.id;
    _service.markConversationRead(widget.amigo.id).then((_) => _center?.refreshCounts(),
        onError: (e) => debugPrint('Erro ao marcar como lida: $e'));
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await _service.sendMessage(widget.amigo.id, text);
      _messageController.clear();
      _upsert(sent);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: SC.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _service.currentUserId;
    return Scaffold(
      backgroundColor: SC.bg,
      appBar: AppBar(
        backgroundColor: SC.surface,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: SC.outline.withValues(alpha: 0.4))),
        title: Row(
          children: [
            UserAvatar.of(widget.amigo, radius: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.amigo.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  AnimatedSwitcher(
                    duration: SMotion.of(context, SMotion.quick),
                    child: Text(
                      _friendTyping ? 'digitando…' : '@${widget.amigo.username}',
                      key: ValueKey(_friendTyping),
                      style: TextStyle(
                        fontSize: 12,
                        color: _friendTyping ? SC.starSoft : SC.textFaint,
                        fontWeight: _friendTyping ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                if (_messages == null && _loadError != null) {
                  return EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Não foi possível carregar a conversa',
                    message: friendlyError(_loadError!),
                    actionLabel: 'Tentar novamente',
                    onAction: _fetch,
                  );
                }
                if (_messages == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = _messages!;
                WidgetsBinding.instance.addPostFrameCallback((_) => _markRead(all, me));
                final messages = all.reversed.toList();
                if (messages.isEmpty && !_friendTyping) {
                  return Center(
                    child: EmptyState(
                      icon: Icons.waving_hand_rounded,
                      title: 'Diga oi para ${widget.amigo.displayName}',
                      message: 'Que tal indicar o último filme que você amou?',
                    ),
                  );
                }
                // Última mensagem minha já vista: mostra "Visto" só nela.
                final lastSeenMine = messages.firstWhere(
                  (m) => m.senderId == me && m.readAt != null,
                  orElse: () => Message(
                      id: -1, senderId: '', receiverId: '', content: '', createdAt: DateTime(0)),
                );
                final offset = _friendTyping ? 1 : 0;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: messages.length + offset,
                  itemBuilder: (context, index) {
                    if (_friendTyping && index == 0) return const _TypingBubble();
                    final i = index - offset;
                    final m = messages[i];
                    final mine = m.senderId == me;
                    final next = i > 0 ? messages[i - 1] : null;
                    final prev = i + 1 < messages.length ? messages[i + 1] : null;
                    final lastOfGroup = next == null || next.senderId != m.senderId;
                    final newDay = prev == null || !_sameDay(prev.createdAt, m.createdAt);
                    return Column(
                      children: [
                        if (newDay) _DaySeparator(date: m.createdAt),
                        _Bubble(
                          key: ValueKey(m.id),
                          message: m,
                          mine: mine,
                          lastOfGroup: lastOfGroup,
                          seen: mine && m.id == lastSeenMine.id,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: SC.surface,
              border: Border(top: BorderSide(color: SC.outline.withValues(alpha: 0.4))),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(6, 8, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: _isEmojiVisible ? 'Teclado' : 'Emojis',
                    icon: Icon(
                      _isEmojiVisible ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                      color: SC.textMuted,
                    ),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _isEmojiVisible = !_isEmojiVisible);
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      onTap: () => setState(() => _isEmojiVisible = false),
                      style: const TextStyle(color: SC.text),
                      decoration: InputDecoration(
                        hintText: 'Mensagem',
                        counterText: '',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(SRadius.lg)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SRadius.lg),
                          borderSide: BorderSide(color: SC.outline.withValues(alpha: 0.35)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SRadius.lg),
                          borderSide: const BorderSide(color: SC.star, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return AnimatedScale(
                        scale: hasText ? 1 : 0.85,
                        duration: SMotion.of(context, SMotion.quick),
                        curve: SMotion.emphasized,
                        child: IconButton.filled(
                          tooltip: 'Enviar',
                          style: IconButton.styleFrom(
                            backgroundColor: SC.primary,
                            disabledBackgroundColor: SC.surfaceHigher,
                            fixedSize: const Size(46, 46),
                          ),
                          onPressed: hasText && !_sending ? _sendMessage : null,
                          icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: SMotion.of(context, SMotion.medium),
            curve: SMotion.emphasized,
            child: _isEmojiVisible
                ? SizedBox(
                    height: 260,
                    child: EmojiPicker(
                      textEditingController: _messageController,
                      config: Config(
                        height: 260,
                        checkPlatformCompatibility: true,
                        emojiViewConfig: EmojiViewConfig(
                          backgroundColor: SC.surface,
                          emojiSizeMax: 28 *
                              (foundation.defaultTargetPlatform == TargetPlatform.iOS
                                  ? 1.2
                                  : 1.0),
                        ),
                        categoryViewConfig: const CategoryViewConfig(
                          backgroundColor: SC.surface,
                          indicatorColor: SC.star,
                          iconColorSelected: SC.star,
                          iconColor: SC.textFaint,
                        ),
                        bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                        searchViewConfig: const SearchViewConfig(backgroundColor: SC.surface),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Balão de mensagem que entra com escala a partir do lado de quem enviou.
class _Bubble extends StatefulWidget {
  final Message message;
  final bool mine;
  final bool lastOfGroup;
  final bool seen;

  const _Bubble({
    super.key,
    required this.message,
    required this.mine,
    required this.lastOfGroup,
    this.seen = false,
  });

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: SMotion.medium);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    // Só anima mensagens recentes; o histórico aparece pronto.
    final fresh = DateTime.now().difference(widget.message.createdAt).inSeconds.abs() < 10;
    if (fresh && !SMotion.reduced(context)) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final mine = widget.mine;
    final t = m.createdAt.toLocal();
    const r = Radius.circular(18);
    const tail = Radius.circular(6);
    final anim = CurvedAnimation(parent: _c, curve: SMotion.emphasized);

    final bubble = Padding(
      padding: EdgeInsets.only(top: 2, bottom: widget.lastOfGroup && !widget.seen ? 10 : 2),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(anim),
            alignment: mine ? Alignment.bottomRight : Alignment.bottomLeft,
            child: Container(
              constraints:
                  BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
              decoration: BoxDecoration(
                gradient: mine ? SC.buttonGradient : null,
                color: mine ? null : SC.surfaceHigh,
                borderRadius: BorderRadius.only(
                  topLeft: r,
                  topRight: r,
                  bottomLeft: !mine && widget.lastOfGroup ? tail : r,
                  bottomRight: mine && widget.lastOfGroup ? tail : r,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(m.content,
                      style: const TextStyle(color: SC.text, fontSize: 15, height: 1.4)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: mine ? const Color(0xFFE6DCFF) : SC.textFaint,
                          fontSize: 10.5,
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 3),
                        AnimatedSwitcher(
                          duration: SMotion.of(context, SMotion.quick),
                          child: Icon(
                            m.readAt != null ? Icons.done_all_rounded : Icons.done_rounded,
                            key: ValueKey(m.readAt != null),
                            size: 14,
                            color: m.readAt != null ? Colors.white : const Color(0xFFCDBEFF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!widget.seen) return bubble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        bubble,
        const Padding(
          padding: EdgeInsets.only(right: 4, bottom: 10),
          child: Text('Visto', style: TextStyle(color: SC.textFaint, fontSize: 11)),
        ),
      ],
    );
  }
}

bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

class _DaySeparator extends StatelessWidget {
  final DateTime date;

  const _DaySeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final d = date.toLocal();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final label = _sameDay(d, now)
        ? 'Hoje'
        : _sameDay(d, now.subtract(const Duration(days: 1)))
            ? 'Ontem'
            : '${two(d.day)}/${two(d.month)}/${d.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: SC.surface,
            borderRadius: BorderRadius.circular(SRadius.pill),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: SC.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

/// Balão com três pontinhos pulsando em sequência ("digitando…").
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Entrance(
        offsetY: 6,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: SC.surfaceHigh,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(6),
            ),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // Cada ponto sobe e acende com 150ms de defasagem.
                final t = ((_c.value - i * 0.15) % 1.0);
                final wave = t < 0.4 ? math.sin(t / 0.4 * math.pi) : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Transform.translate(
                    offset: Offset(0, -4 * wave),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Color.lerp(SC.textFaint, SC.starSoft, wave),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
