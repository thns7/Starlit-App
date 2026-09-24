import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlitfilms/components/new_review_sheet.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/review.dart';
import 'package:starlitfilms/screens/Perfil/editar_perfil.dart';
import 'package:starlitfilms/screens/review.dart';
import 'package:starlitfilms/services/supabase_service.dart';

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
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
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
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2A1266), Color(0xFF150B2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            child: Column(
              children: [
                SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(5),
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF462F7E), Color(0xFF7E56E4)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(40)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(url: authProvider.avatar, radius: 40),
                            const Spacer(),
                            _statColumn("Amigos", '$_friendCount'),
                            _verticalDivider(),
                            _statColumn("Posts", '${_reviews.length}'),
                            _verticalDivider(),
                            _statColumn("Likes", '$_likesReceived'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (authProvider.nome?.isNotEmpty ?? false)
                              ? authProvider.nome!
                              : (authProvider.username ?? ''),
                          style: TextStyle(
                            fontSize: screenWidth * 0.07,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@${authProvider.username ?? ''}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                        if (authProvider.descricao?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 8),
                          Text(
                            authProvider.descricao!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontFamily: 'Poppins',
                              color: Colors.white70,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _pillButton('Editar Perfil', () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const EditarPerfil()),
                                );
                              }),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _pillButton('Compartilhar Perfil', () {
                                Clipboard.setData(ClipboardData(
                                    text: 'Me siga no Starlit: @${authProvider.username}'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Seu @ foi copiado!'),
                                    backgroundColor: Color(0xff7E56E4),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                _tabSwitch(screenWidth, screenHeight),
                SizedBox(height: screenHeight * 0.015),
                if (isPostsSelected)
                  SizedBox(
                    width: screenWidth * 0.9,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (await showNewReviewSheet(context)) _load();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff7E56E4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 10,
                      ),
                      child: const Text(
                        'Novo Post',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(child: _tabContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final isEmpty = isPostsSelected ? _reviews.isEmpty : _comments.isEmpty;
    return RefreshIndicator(
      onRefresh: _load,
      child: isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    isPostsSelected
                        ? 'Você ainda não publicou nenhuma review.'
                        : 'Você ainda não comentou nenhuma review.',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: isPostsSelected ? _reviews.length : _comments.length,
              itemBuilder: (context, index) {
                if (isPostsSelected) {
                  final review = _reviews[index];
                  return ReviewListTile(
                      review: review, onTap: () => _openReview(review));
                }
                final comment = _comments[index];
                return GestureDetector(
                  onTap: () => _openReviewById(comment.reviewId),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A267F),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Em: ${comment.movieTitle ?? 'review'}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(comment.content,
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _tabSwitch(double screenWidth, double screenHeight) {
    return Container(
      width: screenWidth * 0.8,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment:
                isPostsSelected ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              width: screenWidth * 0.4,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
          Row(
            children: [
              _tabLabel('Posts', true, screenWidth),
              _tabLabel('Comentários', false, screenWidth),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabLabel(String text, bool posts, double screenWidth) {
    final selected = isPostsSelected == posts;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => isPostsSelected = posts),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              color: selected ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillButton(String text, VoidCallback onPressed) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff9670F5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 10,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: FittedBox(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white70,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
