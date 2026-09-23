import 'package:flutter/material.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/review.dart';
import 'package:starlitfilms/screens/biblioteca.dart';
import 'package:starlitfilms/services/supabase_service.dart';

/// Detalhe de uma review: curtir, comentar e (se for sua) apagar.
/// Retorna a review atualizada (ou null se foi apagada) via Navigator.pop.
class ReviewDetailPage extends StatefulWidget {
  final Review review;

  const ReviewDetailPage({super.key, required this.review});

  @override
  State<ReviewDetailPage> createState() => _ReviewDetailPageState();
}

class _ReviewDetailPageState extends State<ReviewDetailPage> {
  final _service = SupabaseService.instance;
  final _commentController = TextEditingController();

  late Review _review = widget.review;
  List<Comment> _comments = [];
  bool _loadingComments = true;
  bool _sending = false;
  bool _deleted = false;

  bool get _isMine => _review.author.id == _service.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
    );
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _service.fetchComments(_review.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _review = _review.copyWith(commentCount: comments.length);
      });
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _toggleLike() async {
    final liked = !_review.likedByMe;
    final previous = _review;
    setState(() {
      _review = _review.copyWith(
        likedByMe: liked,
        likeCount: _review.likeCount + (liked ? 1 : -1),
      );
    });
    try {
      await _service.setLike(_review.id, liked);
    } catch (e) {
      if (mounted) setState(() => _review = previous);
      _showError(e);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.addComment(_review.id, text);
      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();
      await _loadComments();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    try {
      await _service.deleteComment(comment.id);
      await _loadComments();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteReview() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF150B2E),
        title: const Text('Apagar review?', style: TextStyle(color: Colors.white)),
        content: const Text('Essa ação não pode ser desfeita.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apagar', style: TextStyle(color: Color(0xffFE2137))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteReview(_review.id);
      _deleted = true;
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showError(e);
    }
  }

  void _openProfile(String userId) {
    if (userId == _service.currentUserId) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BibliotecaPage(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_deleted ? null : _review);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFF150B2E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (_isMine)
              IconButton(
                tooltip: 'Apagar review',
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: _deleteReview,
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadComments,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    SizedBox(
                      height: 280,
                      child: MoviePosterBackground(
                        posterUrl: _review.movie.posterUrl,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 90, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _review.movie.label,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              StarRow(rating: _review.rating, size: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      onTap: () => _openProfile(_review.author.id),
                      leading: UserAvatar.of(_review.author),
                      title: Text(_review.author.displayName,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text('@${_review.author.username} · ${_formatDate(_review.createdAt)}',
                          style: const TextStyle(color: Colors.white54)),
                      trailing: _review.isPublic
                          ? null
                          : const Tooltip(
                              message: 'Só para amigos',
                              child: Icon(Icons.group, color: Colors.white54),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _review.content,
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _toggleLike,
                            icon: Icon(
                              _review.likedByMe ? Icons.favorite : Icons.favorite_border,
                              color: starColor,
                            ),
                          ),
                          Text('${_review.likeCount}',
                              style: const TextStyle(color: Colors.white)),
                          const SizedBox(width: 16),
                          const Icon(Icons.chat_bubble_outline, color: starColor),
                          const SizedBox(width: 8),
                          Text('${_review.commentCount}',
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    if (_loadingComments)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('Nenhum comentário ainda. Seja o primeiro!',
                              style: TextStyle(color: Colors.white54)),
                        ),
                      )
                    else
                      ..._comments.map((c) => ListTile(
                            leading: GestureDetector(
                              onTap: () => _openProfile(c.author.id),
                              child: UserAvatar.of(c.author, radius: 18),
                            ),
                            title: Text('@${c.author.username}',
                                style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            subtitle: Text(c.content,
                                style: const TextStyle(color: Colors.white, fontSize: 15)),
                            trailing: c.author.id == _service.currentUserId
                                ? IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                                    onPressed: () => _deleteComment(c),
                                  )
                                : null,
                          )),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                color: const Color(0xFF2C2247),
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        maxLength: 2000,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Escreva um comentário...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _sendComment,
                      icon: const Icon(Icons.send, color: starColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final d = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}
