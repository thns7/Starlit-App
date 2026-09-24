import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/message.dart';
import 'package:starlitfilms/models/profile.dart';
import 'package:starlitfilms/services/supabase_service.dart';

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
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
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
      backgroundColor: const Color(0xFF150B2E),
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Row(
          children: [
            UserAvatar.of(widget.amigo),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.amigo.displayName, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF5936B2),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(friendlyError(snapshot.error!),
                        style: const TextStyle(color: Colors.white70)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.reversed.toList();
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Diga oi! 👋', style: TextStyle(color: Colors.white54)),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final mine = m.senderId == me;
                    final time = m.createdAt.toLocal();
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: mine ? const Color(0xff7E56E4) : const Color(0xFF3A267F),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(m.content,
                                style: const TextStyle(color: Colors.white, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: const Color(0xFF2C2247),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isEmojiVisible ? Icons.keyboard : Icons.emoji_emotions,
                      color: Colors.white70,
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
                      onTap: () => setState(() => _isEmojiVisible = false),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Digite uma mensagem...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xff9670F5)),
                    onPressed: _sending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
          Offstage(
            offstage: !_isEmojiVisible,
            child: SizedBox(
              height: 250,
              child: EmojiPicker(
                textEditingController: _messageController,
                config: Config(
                  height: 250,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 28 *
                        (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
