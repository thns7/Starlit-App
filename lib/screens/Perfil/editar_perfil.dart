import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/screens/entrar.dart';
import 'package:starlitfilms/theme/tokens.dart';

class EditarPerfil extends StatefulWidget {
  const EditarPerfil({super.key});

  @override
  State<EditarPerfil> createState() => _EditarPerfilState();
}

class _EditarPerfilState extends State<EditarPerfil> with TickerProviderStateMixin {
  late TextEditingController _nomeController;
  late TextEditingController _usernameController;
  late TextEditingController _descricaoController;

  late AnimationController _animationController;
  late Animation<Offset> _imageAnimation;

  Uint8List? _newAvatarBytes;
  String? _newAvatarExtension;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _nomeController = TextEditingController(text: authProvider.nome);
    _usernameController = TextEditingController(text: authProvider.username);
    _descricaoController = TextEditingController(text: authProvider.descricao);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _imageAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nomeController.dispose();
    _usernameController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _newAvatarBytes = bytes;
      _newAvatarExtension = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: SC.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [SC.bgTop, SC.bg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: 300,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SlideTransition(
                        position: _imageAnimation,
                        child: Image.asset(
                          'assets/detalheEditarPerfil.png',
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x66050210),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: _newAvatarBytes != null
                                ? CircleAvatar(
                                    radius: 80,
                                    backgroundImage: MemoryImage(_newAvatarBytes!),
                                  )
                                : UserAvatar(url: authProvider.avatar, radius: 80),
                          ),
                          const Positioned(
                            right: 8,
                            bottom: 8,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: SC.primary,
                              child: Icon(Icons.photo_camera_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField("Nome", _nomeController, Icons.person),
                    const SizedBox(height: 24),
                    _buildTextField("Username", _usernameController, Icons.alternate_email),
                    const SizedBox(height: 24),
                    _buildTextField("Descrição", _descricaoController, Icons.description,
                        maxLines: 3),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      label: 'Salvar alterações',
                      loading: _saving,
                      onPressed: () => _salvarAlteracoes(authProvider),
                    ),
                    const SizedBox(height: 36),
                    const Divider(),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.logout_rounded, color: SC.danger),
                      title: const Text('Sair da conta',
                          style: TextStyle(color: SC.danger, fontWeight: FontWeight.w600)),
                      onTap: () => _showLogoutDialog(context, authProvider),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: 1,
      style: const TextStyle(color: SC.text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Future<void> _salvarAlteracoes(AuthProvider authProvider) async {
    final username = _usernameController.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.]{3,30}$').hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('O username deve ter de 3 a 30 caracteres: letras, números, "_" ou "."'),
        backgroundColor: SC.danger,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      await authProvider.updateProfile(
        nome: _nomeController.text,
        username: username,
        descricao: _descricaoController.text,
        avatarBytes: _newAvatarBytes,
        avatarExtension: _newAvatarExtension,
      );
      if (!mounted) return;
      setState(() => _newAvatarBytes = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alterações salvas com sucesso!'),
                  ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: SC.danger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Image.asset('assets/icon_door.png', width: 56, height: 56),
      title: const Text('Sair do Starlit?', textAlign: TextAlign.center),
      content: const Text(
        'Você pode entrar de novo quando quiser com seu email e senha.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Ficar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: SC.danger),
          onPressed: () async {
            final navigator = Navigator.of(context);
            Navigator.of(dialogContext).pop();
            await authProvider.logout();
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const Entrar()),
              (route) => false,
            );
          },
          child: const Text('Sair'),
        ),
      ],
    ),
  );
}
}
