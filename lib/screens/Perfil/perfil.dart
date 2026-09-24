import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/new_review_sheet.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/review.dart';
import 'package:starlitfilms/screens/Perfil/editar_perfil.dart';
import 'package:starlitfilms/screens/review.dart';
import 'package:starlitfilms/services/supabase_service.dart';
import 'package:starlitfilms/theme/tokens.dart';

class Perfil extends StatefulWidget {
  const Perfil({super.key});

  @override
  State<Perfil> createState() => _PerfilState();
}

class _PerfilState extends State<Perfil> with TickerProviderStateMixin {
  final _service = SupabaseService.instance;
  bool isPostsSelected = true;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  List<Review> _reviews = [];
  List<Comment> _comments = [];
  int _friendCount = 0;
  int _likesReceived = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
    _load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = _service.currentUserId;
    if (userId == null) return;
    try {
      final results = await Future.wait([
        _service.fetchUserReviews(userId),
        _service.fetchUserComments(userId),
        _service.fetchFriends(),
        _service.countLikesReceived(userId),
      ]);
      if (!mounted) return;
      setState(() {
        _reviews = results[0] as List<Review>;
        _comments = results[1] as List<Comment>;
        _friendCount = (results[2] as List).length;
        _likesReceived = results[3] as int;
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

  Future<void> _openReview(Review review) async {
    await Navigator.push<Review?>(
      context,
      MaterialPageRoute(builder: (_) => ReviewDetailPage(review: review)),
    );
    _load();
  }

  Future<void> _openReviewById(int reviewId) async {
    try {
      final review = await _service.fetchReview(reviewId);
      if (review != null && mounted) _openReview(review);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: SC.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final name = (auth.nome?.isNotEmpty ?? false) ? auth.nome! : (auth.username ?? '');

    return SkyBackground(
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
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(SSpace.page, 12, SSpace.page, 0),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      decoration: BoxDecoration(
                        gradient: SC.heroGradient,
                        borderRadius: BorderRadius.circular(SRadius.xl),
                        boxShadow: SShadow.raised,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle, color: Colors.white24),
                                child: UserAvatar(url: auth.avatar, radius: 38),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.4,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '@${auth.username ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 14, color: Color(0xFFE6DCFF)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (auth.descricao?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 14),
                            Text(
                              auth.descricao!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, height: 1.45, color: Color(0xFFEDE6FF)),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0x33150B2E),
                              borderRadius: BorderRadius.circular(SRadius.lg),
                            ),
                            child: Row(
                              children: [
                                _stat('Amigos', _friendCount),
                                _divider(),
                                _stat('Reviews', _reviews.length),
                                _divider(),
                                _stat('Curtidas', _likesReceived),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _pillButton(Icons.edit_rounded, 'Editar perfil', () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EditarPerfil()),
                                  );
                                }),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _pillButton(Icons.ios_share_rounded, 'Compartilhar', () {
                                  Clipboard.setData(ClipboardData(
                                      text: 'Me siga no Starlit: @${auth.username}'));
                                  showStarlitToast(context, 'Seu @ foi copiado',
                                      icon: Icons.content_copy_rounded);
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(SSpace.page, 22, SSpace.page, 12),
                child: Row(
                  children: [
                    Expanded(child: _tabSwitch()),
                    if (isPostsSelected) ...[
                      const SizedBox(width: 10),
                      Tooltip(
                        message: 'Nova review',
                        child: Pressable(
                          onTap: () async {
                            if (await showNewReviewSheet(context)) _load();
                          },
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: SC.buttonGradient,
                              borderRadius: BorderRadius.circular(SRadius.md),
                              boxShadow: SShadow.glowButton,
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ..._tabContent(),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  List<Widget> _tabContent() {
    if (_loading) {
      return [
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: SSpace.page),
          sliver: SliverToBoxAdapter(
            child: Column(children: [
              Skeleton(height: 104, radius: SRadius.lg),
              SizedBox(height: 12),
              Skeleton(height: 104, radius: SRadius.lg),
            ]),
          ),
        ),
      ];
    }
    final isEmpty = isPostsSelected ? _reviews.isEmpty : _comments.isEmpty;
    if (isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: isPostsSelected ? Icons.movie_filter_rounded : Icons.forum_rounded,
            title: isPostsSelected
                ? 'Você ainda não publicou reviews'
                : 'Você ainda não comentou',
            message: isPostsSelected
                ? 'Conte o que achou do último filme que você viu.'
                : 'Os comentários que você fizer aparecem aqui.',
            actionLabel: isPostsSelected ? 'Escrever review' : null,
            onAction: isPostsSelected
                ? () async {
                    if (await showNewReviewSheet(context)) _load();
                  }
                : null,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: SSpace.page),
        sliver: SliverList.builder(
          itemCount: isPostsSelected ? _reviews.length : _comments.length,
          itemBuilder: (context, i) {
            if (isPostsSelected) {
              final review = _reviews[i];
              return Entrance(
                key: ValueKey('r${review.id}'),
                index: i,
                child: ReviewListTile(review: review, onTap: () => _openReview(review)),
              );
            }
            final comment = _comments[i];
            return Entrance(
              key: ValueKey('c${comment.id}'),
              index: i,
              child: Pressable(
                pressedScale: 0.98,
                onTap: () => _openReviewById(comment.reviewId),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SC.surface,
                    borderRadius: BorderRadius.circular(SRadius.lg),
                    border: Border.all(color: SC.outline.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.movie_rounded, size: 14, color: SC.starSoft),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              comment.movieTitle ?? 'Review',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: SC.starSoft,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 18, color: SC.textFaint),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(comment.content,
                          style: const TextStyle(color: SC.text, height: 1.45)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _tabSwitch() {
    final d = SMotion.of(context, SMotion.medium);
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
            alignment: isPostsSelected ? Alignment.centerLeft : Alignment.centerRight,
            duration: d,
            curve: SMotion.emphasized,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: SC.surfaceHigher,
                  borderRadius: BorderRadius.circular(SRadius.sm),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _tabLabel('Reviews', true),
              _tabLabel('Comentários', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabLabel(String text, bool posts) {
    final selected = isPostsSelected == posts;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => isPostsSelected = posts),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: SMotion.of(context, SMotion.quick),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? SC.text : SC.textFaint,
              ),
              child: Text(text),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillButton(IconData icon, String text, VoidCallback onPressed) {
    return Pressable(
      onTap: onPressed,
      semanticLabel: text,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(SRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: SMotion.of(context, const Duration(milliseconds: 700)),
            curve: SMotion.emphasized,
            builder: (context, v, _) => Text(
              v.round().toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(label, style: const TextStyle(color: Color(0xFFE6DCFF), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: Colors.white24);
}
