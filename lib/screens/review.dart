import 'package:flutter/material.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/models/review.dart';
import 'package:starlitfilms/screens/filme.dart';
import 'package:starlitfilms/screens/biblioteca.dart';
import 'package:starlitfilms/services/supabase_service.dart';
import 'package:starlitfilms/theme/tokens.dart';

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
      SnackBar(content: Text(friendlyError(e)), backgroundColor: SC.danger),
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
        title: const Text('Apagar esta review?'),
        content: const Text(
            'A review, as curtidas e os comentários dela serão apagados. Não dá para desfazer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SC.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apagar review'),
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

  void _openMovie() {
    if (_review.movie.tmdbId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailPage(
          movie: TmdbMovie.fromMovie(_review.movie),
          heroTag: 'review-poster-${_review.id}-detail',
        ),
      ),
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
        backgroundColor: SC.bg,
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.all(6),
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(backgroundColor: SC.bg.withValues(alpha: 0.6)),
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          actions: [
            if (_isMine)
              Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(backgroundColor: SC.bg.withValues(alpha: 0.6)),
                  tooltip: 'Apagar review',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _deleteReview,
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadComments,
                color: SC.star,
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  children: [
                    SizedBox(
                      height: 320,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: 'review-poster-${_review.id}',
                            createRectTween: posterFlight,
                            child: PosterImage(url: _review.movie.posterUrl),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x55150B2E), Color(0x88150B2E), SC.bg],
                                stops: [0, 0.55, 1],
                              ),
                            ),
                          ),
                          Positioned(
                            left: SSpace.page,
                            right: SSpace.page,
                            bottom: 12,
                            child: Entrance(
                              baseDelay: const Duration(milliseconds: 150),
                              child: Pressable(
                                onTap: _review.movie.tmdbId == null ? null : _openMovie,
                                pressedScale: 0.98,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _review.movie.label,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                        height: 1.15,
                                        color: SC.text,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        StarRow(rating: _review.rating, size: 22),
                                        if (_review.movie.tmdbId != null) ...[
                                          const Spacer(),
                                          const Text('Ver filme',
                                              style: TextStyle(
                                                  color: SC.starSoft,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13)),
                                          const Icon(Icons.chevron_right_rounded,
                                              color: SC.starSoft, size: 20),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Entrance(
                      index: 1,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(SSpace.page, 8, SSpace.page, 0),
                        child: Row(
                          children: [
                            Pressable(
                              onTap: () => _openProfile(_review.author.id),
                              child: UserAvatar.of(_review.author, radius: 20, ring: true),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_review.author.displayName,
                                      style: const TextStyle(
                                          color: SC.text, fontWeight: FontWeight.w600)),
                                  Text(
                                    '@${_review.author.username} · ${_formatDate(_review.createdAt)}',
                                    style: const TextStyle(color: SC.textFaint, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            if (!_review.isPublic)
                              const Tooltip(
                                message: 'Só para amigos',
                                child: Icon(Icons.group_rounded, color: SC.textFaint),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Entrance(
                      index: 2,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(SSpace.page, 16, SSpace.page, 4),
                        child: Text(
                          _review.content,
                          style: const TextStyle(fontSize: 16, color: SC.text, height: 1.6),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: SSpace.page - 8),
                      child: Row(
                        children: [
                          LikeButton(
                            liked: _review.likedByMe,
                            count: _review.likeCount,
                            onTap: _toggleLike,
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chat_bubble_outline_rounded,
                              color: SC.textMuted, size: 21),
                          const SizedBox(width: 6),
                          Text('${_review.commentCount}',
                              style: const TextStyle(
                                  color: SC.text, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Divider(height: 24, indent: SSpace.page, endIndent: SSpace.page),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(SSpace.page, 0, SSpace.page, 8),
                      child: Text('Comentários',
                          style: TextStyle(
                              color: SC.text, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    if (_loadingComments)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: SSpace.page),
                        child: Column(children: [
                          Skeleton(height: 56),
                          SizedBox(height: 10),
                          Skeleton(height: 56),
                        ]),
                      )
                    else if (_comments.isEmpty)
                      const EmptyState(
                        icon: Icons.forum_rounded,
                        title: 'Nenhum comentário ainda',
                        message: 'Comece a conversa sobre esta review.',
                      )
                    else
                      for (var i = 0; i < _comments.length; i++)
                        Entrance(
                          key: ValueKey(_comments[i].id),
                          index: i,
                          child: _CommentTile(
                            comment: _comments[i],
                            isMine: _comments[i].author.id == _service.currentUserId,
                            onAuthorTap: () => _openProfile(_comments[i].author.id),
                            onDelete: () => _deleteComment(_comments[i]),
                          ),
                        ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _Composer(
              controller: _commentController,
              sending: _sending,
              onSend: _sendComment,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final bool isMine;
  final VoidCallback onAuthorTap;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.isMine,
    required this.onAuthorTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SSpace.page, 6, SSpace.page - 4, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(onTap: onAuthorTap, child: UserAvatar.of(comment.author, radius: 17)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                color: SC.surface,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(SRadius.md),
                  bottomLeft: Radius.circular(SRadius.md),
                  bottomRight: Radius.circular(SRadius.md),
                  topLeft: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${comment.author.username}',
                      style: const TextStyle(
                          color: SC.starSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(comment.content,
                      style: const TextStyle(color: SC.text, fontSize: 14.5, height: 1.45)),
                ],
              ),
            ),
          ),
          if (isMine)
            IconButton(
              tooltip: 'Apagar comentário',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, color: SC.textFaint, size: 18),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

/// Campo de comentário com botão de enviar que acende quando há texto.
class _Composer extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.sending, required this.onSend});

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: SC.surface,
        border: Border(top: BorderSide(color: SC.outline.withValues(alpha: 0.4))),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(SSpace.page, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                maxLength: 2000,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: SC.text),
                decoration: InputDecoration(
                  hintText: 'Escreva um comentário',
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
            AnimatedScale(
              scale: hasText ? 1 : 0.85,
              duration: SMotion.of(context, SMotion.quick),
              curve: SMotion.emphasized,
              child: AnimatedOpacity(
                opacity: hasText ? 1 : 0.45,
                duration: SMotion.of(context, SMotion.quick),
                child: IconButton.filled(
                  tooltip: 'Enviar comentário',
                  style: IconButton.styleFrom(
                    backgroundColor: SC.primary,
                    fixedSize: const Size(46, 46),
                  ),
                  onPressed: hasText && !widget.sending ? widget.onSend : null,
                  icon: widget.sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
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
