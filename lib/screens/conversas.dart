import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/message.dart';
import 'package:starlitfilms/models/profile.dart';
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
  late final Stream<List<Message>> _stream =
      _service.conversationStream(widget.amigo.id);
  bool _isEmojiVisible = false;
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(widget.amigo.id, text);
      _messageController.clear();
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
                  Text('@${widget.amigo.username}',
                      style: const TextStyle(fontSize: 12, color: SC.textFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Não foi possível carregar a conversa',
                    message: friendlyError(snapshot.error!),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.reversed.toList();
                if (messages.isEmpty) {
                  return Center(
                    child: EmptyState(
                      icon: Icons.waving_hand_rounded,
                      title: 'Diga oi para ${widget.amigo.displayName}',
                      message: 'Que tal indicar o último filme que você amou?',
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final mine = m.senderId == me;
                    // Agrupa mensagens seguidas da mesma pessoa.
                    final next = index > 0 ? messages[index - 1] : null;
                    final lastOfGroup = next == null || next.senderId != m.senderId;
                    return _Bubble(
                      key: ValueKey(m.id),
                      message: m,
                      mine: mine,
                      lastOfGroup: lastOfGroup,
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

  const _Bubble({
    super.key,
    required this.message,
    required this.mine,
    required this.lastOfGroup,
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

    return Padding(
      padding: EdgeInsets.only(top: 2, bottom: widget.lastOfGroup ? 10 : 2),
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
                  Text(
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: mine ? const Color(0xFFE6DCFF) : SC.textFaint,
                      fontSize: 10.5,
                    ),
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
