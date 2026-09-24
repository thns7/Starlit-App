import 'package:flutter/material.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/profile.dart';
import 'package:starlitfilms/models/review.dart';
import 'package:starlitfilms/screens/conversas.dart';
import 'package:starlitfilms/screens/review.dart';
import 'package:starlitfilms/services/supabase_service.dart';

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
      SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
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
      backgroundColor: const Color(0xFF150B2E),
      appBar: AppBar(
        title: Text(profile != null ? '@${profile.username}' : ''),
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromARGB(255, 61, 25, 66),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? const Center(
                  child: Text('Usuário não encontrado.',
                      style: TextStyle(color: Colors.white70)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(child: UserAvatar.of(profile, radius: 50)),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          profile.displayName,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      if (profile.bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Text(profile.bio,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _friendAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _status == null || _status == 'received'
                                  ? const Color(0xff7E56E4)
                                  : Colors.white24,
                            ),
                            child: Text(
                              switch (_status) {
                                'accepted' => 'Desfazer amizade',
                                'sent' => 'Cancelar pedido',
                                'received' => 'Aceitar pedido',
                                _ => 'Adicionar amigo',
                              },
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          if (_status == 'accepted') ...[
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ChatPage(amigo: profile)),
                              ),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff7E56E4)),
                              icon: const Icon(Icons.chat, color: Colors.white),
                              label: const Text('Conversar',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Reviews',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 8),
                      if (_reviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('Nenhuma review visível.',
                                style: TextStyle(color: Colors.white54)),
                          ),
                        )
                      else
                        ..._reviews.map((r) => ReviewListTile(
                              review: r,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ReviewDetailPage(review: r)),
                                );
                                _load();
                              },
                            )),
                    ],
                  ),
                ),
    );
  }
}
