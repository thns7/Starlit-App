import 'dart:async';

import 'package:flutter/material.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/profile.dart';
import 'package:starlitfilms/screens/biblioteca.dart';
import 'package:starlitfilms/screens/conversas.dart';
import 'package:starlitfilms/services/supabase_service.dart';

const _bgColor = Color.fromARGB(255, 61, 25, 66);

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

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        _service.fetchFriends(),
        _service.fetchIncomingRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _amigos = results[0]..sort((a, b) => a.displayName.compareTo(b.displayName));
        _pedidos = results[1];
      });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: const Color(0xff7E56E4)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    }
  }

  void _openChat(Profile amigo) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(amigo: amigo)),
    );
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
      backgroundColor: const Color(0xFF2C2247),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.white),
              title: const Text('Conversar', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _openChat(amigo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white),
              title: const Text('Ver perfil', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _openProfile(amigo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Color(0xffFE2137)),
              title: const Text('Desfazer amizade', style: TextStyle(color: Color(0xffFE2137))),
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
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 140),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text('Amigos',
                          style: TextStyle(
                              fontSize: 24, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      ),
                    if (_pedidos.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('Pedidos de amizade',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ),
                      ..._pedidos.map((p) => ListTile(
                            onTap: () => _openProfile(p),
                            leading: UserAvatar.of(p, radius: 24),
                            title: Text(p.displayName, style: const TextStyle(color: Colors.white)),
                            subtitle: Text('@${p.username}',
                                style: const TextStyle(color: Colors.white54)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Aceitar',
                                  icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                                  onPressed: () => _run(
                                      () => _service.acceptFriendRequest(p.id),
                                      'Agora vocês são amigos!'),
                                ),
                                IconButton(
                                  tooltip: 'Recusar',
                                  icon: const Icon(Icons.cancel, color: Colors.white54),
                                  onPressed: () => _run(
                                      () => _service.removeFriendship(p.id), 'Pedido recusado.'),
                                ),
                              ],
                            ),
                          )),
                      const Divider(color: Colors.white24),
                    ],
                    if (_amigos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Você ainda não tem amigos no Starlit.\nToque no + para encontrar pessoas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      ..._amigos.map((amigo) => ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            onTap: () => _openChat(amigo),
                            onLongPress: () => _showFriendOptions(amigo),
                            leading: UserAvatar.of(amigo, radius: 30),
                            title: Text(
                              amigo.displayName,
                              style: const TextStyle(fontSize: 20, color: Colors.white),
                            ),
                            subtitle: Text('@${amigo.username}',
                                style: const TextStyle(color: Colors.white54)),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.white70),
                              onPressed: () => _showFriendOptions(amigo),
                            ),
                          )),
                  ],
                ),
              ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          onPressed: _openSearch,
          backgroundColor: Colors.purple,
          tooltip: 'Encontrar pessoas',
          child: const Icon(Icons.person_add, color: Colors.white),
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
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
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
          break;
        case 'received':
          await _service.acceptFriendRequest(p.id);
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
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _actionButton(Profile p) {
    final status = _status[p.id];
    final (label, color) = switch (status) {
      'accepted' => ('Amigos', Colors.white24),
      'sent' => ('Cancelar', Colors.white24),
      'received' => ('Aceitar', Colors.green),
      _ => ('Adicionar', const Color(0xff7E56E4)),
    };
    return ElevatedButton(
      onPressed: status == 'accepted' ? null : () => _action(p),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color,
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), _search);
          },
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Buscar por nome ou @username',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Colors.white70),
          ),
        ),
      ),
      body: _loading && _results.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(
                  child: Text('Nenhum usuário encontrado.',
                      style: TextStyle(color: Colors.white70)),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final p = _results[index];
                    return ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BibliotecaPage(userId: p.id)),
                      ).then((_) => _search()),
                      leading: UserAvatar.of(p, radius: 24),
                      title: Text(p.displayName, style: const TextStyle(color: Colors.white)),
                      subtitle:
                          Text('@${p.username}', style: const TextStyle(color: Colors.white54)),
                      trailing: _actionButton(p),
                    );
                  },
                ),
    );
  }
}
