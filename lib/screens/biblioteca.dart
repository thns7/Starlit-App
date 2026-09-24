import 'package:flutter/material.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/profile.dart';
import 'package:starlitfilms/models/review.dart';
import 'package:starlitfilms/screens/conversas.dart';
import 'package:starlitfilms/screens/review.dart';
import 'package:starlitfilms/services/supabase_service.dart';
import 'package:starlitfilms/theme/tokens.dart';

/// Perfil público de outro usuário: dados, status de amizade e reviews visíveis.
class BibliotecaPage extends StatefulWidget {
  final String userId;

  const BibliotecaPage({super.key, required this.userId});

  @override
  State<BibliotecaPage> createState() => _BibliotecaPageState();
}

class _BibliotecaPageState extends State<BibliotecaPage> {
  final _service = SupabaseService.instance;
  Profile? _profile;
  List<Review> _reviews = [];
  String? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.fetchProfile(widget.userId),
        _service.fetchUserReviews(widget.userId),
        _service.fetchRelationshipStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Profile?;
        _reviews = results[1] as List<Review>;
        _status = (results[2] as Map<String, String>)[widget.userId];
      });
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyError(e)), backgroundColor: SC.danger),
    );
  }

  Future<void> _friendAction() async {
    try {
      switch (_status) {
        case null:
          await _service.sendFriendRequest(widget.userId);
          break;
        case 'received':
          await _service.acceptFriendRequest(widget.userId);
          break;
        default:
          await _service.removeFriendship(widget.userId);
      }
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      backgroundColor: SC.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(profile != null ? '@${profile.username}' : '')),
      body: SkyBackground(
        starCount: 40,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : profile == null
                ? const Center(
                    child: EmptyState(
                      icon: Icons.person_off_rounded,
                      title: 'Usuário não encontrado',
                      message: 'Talvez a conta tenha sido removida.',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: SC.star,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      padding: EdgeInsets.fromLTRB(SSpace.page,
                          MediaQuery.paddingOf(context).top + kToolbarHeight + 8, SSpace.page, 32),
                      children: [
                        Entrance(
                          child: Column(
                            children: [
                              UserAvatar.of(profile, radius: 48, ring: true),
                              const SizedBox(height: 14),
                              Text(
                                profile.displayName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                    color: SC.text),
                              ),
                              Text('@${profile.username}',
                                  style: const TextStyle(color: SC.textFaint)),
                              if (profile.bio.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(profile.bio,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: SC.textMuted, height: 1.45)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Entrance(
                          index: 1,
                          child: Row(
                            children: [
                              Expanded(
                                child: _status == null || _status == 'received'
                                    ? PrimaryButton(
                                        label: _status == 'received'
                                            ? 'Aceitar pedido'
                                            : 'Adicionar amigo',
                                        icon: Icons.person_add_alt_1_rounded,
                                        onPressed: _friendAction,
                                      )
                                    : OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: SC.textMuted,
                                          minimumSize: const Size(0, 52),
                                          side: BorderSide(
                                              color: SC.outline.withValues(alpha: 0.7)),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(SRadius.md)),
                                        ),
                                        onPressed: _friendAction,
                                        icon: Icon(_status == 'accepted'
                                            ? Icons.person_remove_rounded
                                            : Icons.close_rounded),
                                        label: Text(_status == 'accepted'
                                            ? 'Desfazer amizade'
                                            : 'Cancelar pedido'),
                                      ),
                              ),
                              if (_status == 'accepted') ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: PrimaryButton(
                                    label: 'Conversar',
                                    icon: Icons.chat_bubble_rounded,
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ChatPage(amigo: profile)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text('Reviews',
                            style: TextStyle(
                                color: SC.text, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (_reviews.isEmpty)
                          const EmptyState(
                            icon: Icons.lock_outline_rounded,
                            title: 'Nenhuma review visível',
                            message: 'Algumas reviews só aparecem para amigos.',
                          )
                        else
                          for (var i = 0; i < _reviews.length; i++)
                            Entrance(
                              index: i + 2,
                              child: ReviewListTile(
                                review: _reviews[i],
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ReviewDetailPage(review: _reviews[i])),
                                  );
                                  _load();
                                },
                              ),
                            ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
