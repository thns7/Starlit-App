import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/screens/entrar.dart';

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
      backgroundColor: const Color(0xFF150B2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2A1266), Color(0xFF150B2E)],
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
                                  color: Colors.black.withOpacity(0.3),
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
                              backgroundColor: Color(0xff7E56E4),
                              child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
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
                    Center(
                      child: SizedBox(
                        width: 200,
                        child: ElevatedButton(
                          onPressed: _saving ? null : () => _salvarAlteracoes(authProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff7E56E4),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 10,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(color: Colors.white),
                                )
                              : const Text(
                                  'Salvar',
                                  style: TextStyle(
                                      fontSize: 20,
                                      color: Color(0xffffffff),
                                      fontWeight: FontWeight.w500),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Divider(color: Colors.white54, thickness: 2),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Container(
                        width: 140,
                        height: 55,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextButton(
                          onPressed: () => _showLogoutDialog(context, authProvider),
                          child: const Text(
                            'Sair',
                            style: TextStyle(fontSize: 16, color: Color(0xffFE2137)),
                          ),
                        ),
                      ),
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
      style: const TextStyle(
        fontFamily: "Poppins",
        color: Colors.white,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: "Poppins",
          color: Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Icon(icon, color: Colors.white70),
        ),
        filled: true,
        fillColor: const Color(0xFF5936B2).withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _salvarAlteracoes(AuthProvider authProvider) async {
    final username = _usernameController.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.]{3,30}$').hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('O username deve ter de 3 a 30 caracteres: letras, números, "_" ou "."'),
        backgroundColor: Colors.red,
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
          backgroundColor: Color(0xff7E56E4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        )),
        child: Dialog(
          backgroundColor: const Color(0xFF150B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icon_door.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Oh não! Você está saindo...\nTem certeza?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Nah, to só brincando',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xff7E56E4),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16.0, 
                      horizontal: 24.0, 
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await authProvider.logout();
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const Entrar()),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Sim, desconecte-me',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
}
