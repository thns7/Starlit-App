import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/theme/tokens.dart';
import 'package:starlitfilms/screens/homepage.dart';
import 'package:starlitfilms/screens/login.dart';

class Cadastro extends StatefulWidget {
  const Cadastro({super.key});

  @override
  _CadastroState createState() => _CadastroState();
}

class _CadastroState extends State<Cadastro> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _isLoading = false;
  Uint8List? _avatarBytes;
  String? _avatarExtension;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SC.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(),
      body: SkyBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Entrance(
                        child: Text(
                          'Crie sua conta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: SC.text,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Entrance(
                        index: 1,
                        child: Text(
                          'Suas reviews, seus amigos, seus filmes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: SC.textMuted),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Entrance(
                        index: 1,
                        child: Center(
                          child: Pressable(
                            onTap: _pickAvatar,
                            semanticLabel: 'Escolher foto de perfil',
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    AnimatedSwitcher(
                                      duration: SMotion.of(context, SMotion.medium),
                                      child: CircleAvatar(
                                        key: ValueKey(_avatarBytes?.length),
                                        radius: 46,
                                        backgroundColor: SC.surfaceHigher,
                                        backgroundImage: _avatarBytes != null
                                            ? MemoryImage(_avatarBytes!)
                                            : null,
                                        child: _avatarBytes == null
                                            ? const Icon(Icons.person_rounded,
                                                size: 46, color: SC.textFaint)
                                            : null,
                                      ),
                                    ),
                                    const Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: SC.primary,
                                        child: Icon(Icons.photo_camera_rounded,
                                            size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _avatarBytes == null ? 'Adicionar foto (opcional)' : 'Trocar foto',
                                  style: const TextStyle(color: SC.starSoft, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Entrance(
                        index: 2,
                        child: _buildTextField(_nameController, 'Nome', Icons.person_outline_rounded,
                            autofill: AutofillHints.name),
                      ),
                      const SizedBox(height: 14),
                      Entrance(
                        index: 3,
                        child: _buildTextField(
                            _usernameController, 'Username', Icons.alternate_email_rounded,
                            keyboardType: TextInputType.visiblePassword,
                            autofill: AutofillHints.newUsername,
                            helper: 'Letras minúsculas, números, "_" ou "."'),
                      ),
                      const SizedBox(height: 14),
                      Entrance(
                        index: 4,
                        child: _buildTextField(_emailController, 'Email', Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            autofill: AutofillHints.email),
                      ),
                      const SizedBox(height: 14),
                      Entrance(
                        index: 5,
                        child: _buildTextField(_passwordController, 'Senha', Icons.lock_outline_rounded,
                            isPassword: true,
                            autofill: AutofillHints.newPassword,
                            helper: 'Mínimo de 8 caracteres'),
                      ),
                      const SizedBox(height: 14),
                      Entrance(
                        index: 6,
                        child: _buildTextField(
                            _passwordConfirmController, 'Confirmar senha', Icons.lock_outline_rounded,
                            isPassword: true, isConfirm: true),
                      ),
                      const SizedBox(height: 24),
                      Entrance(
                        index: 6,
                        child: PrimaryButton(
                          label: 'Criar conta',
                          loading: _isLoading,
                          onPressed: () {
                            if (_validateFields()) _registerUser();
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const Login()),
                        ),
                        child: RichText(
                          text: const TextSpan(
                            text: 'Já tem conta? ',
                            style: TextStyle(fontFamily: 'Poppins', color: SC.textMuted),
                            children: [
                              TextSpan(
                                text: 'Entrar',
                                style: TextStyle(
                                    color: SC.starSoft, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SC.danger),
    );
  }

  bool _validateFields() {
    final username = _usernameController.text.trim().toLowerCase();
    final email = _emailController.text.trim();
    if (_nameController.text.trim().isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        _passwordController.text.isEmpty ||
        _passwordConfirmController.text.isEmpty) {
      _showError('Todos os campos devem ser preenchidos');
      return false;
    }
    if (!RegExp(r'^[a-z0-9_.]{3,30}$').hasMatch(username)) {
      _showError('O username deve ter de 3 a 30 caracteres: letras, números, "_" ou "."');
      return false;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showError('Insira um email válido');
      return false;
    }
    if (_passwordController.text.length < 8) {
      _showError('Insira uma senha com no mínimo 8 caracteres');
      return false;
    }
    if (_passwordController.text != _passwordConfirmController.text) {
      _showError('As senhas não coincidem');
      return false;
    }
    return true;
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
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    setState(() {
      _avatarBytes = bytes;
      _avatarExtension = ext;
    });
  }

  Future<void> _registerUser() async {
    setState(() => _isLoading = true);
    try {
      final result = await Provider.of<AuthProvider>(context, listen: false).register(
        nome: _nameController.text,
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        avatarBytes: _avatarBytes,
        avatarExtension: _avatarExtension,
      );
      if (!mounted) return;
      if (result == RegisterResult.loggedIn) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      } else {
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.mark_email_unread_rounded, color: SC.star, size: 40),
            title: const Text('Confirme seu email'),
            content: Text(
              'Enviamos um link de confirmação para ${_emailController.text.trim()}. '
              'Depois de confirmar, faça login. Você pode adicionar sua foto em "Editar Perfil".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Ir para o login'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Login()),
        );
      }
    } catch (e) {
      if (mounted) _showError(friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String labelText,
    IconData icon, {
    bool isPassword = false,
    bool isConfirm = false,
    TextInputType? keyboardType,
    String? autofill,
    String? helper,
  }) {
    final obscured = isConfirm ? _obscurePasswordConfirm : _obscurePassword;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: !isPassword && keyboardType == null,
      obscureText: isPassword && obscured,
      autofillHints: autofill == null ? null : [autofill],
      textInputAction: isConfirm ? TextInputAction.done : TextInputAction.next,
      style: const TextStyle(color: SC.text),
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helper,
        helperStyle: const TextStyle(color: SC.textFaint, fontSize: 12),
        prefixIcon: Icon(icon),
        suffixIcon: isPassword
            ? IconButton(
                tooltip: obscured ? 'Mostrar senha' : 'Esconder senha',
                icon: Icon(obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() {
                  if (isConfirm) {
                    _obscurePasswordConfirm = !_obscurePasswordConfirm;
                  } else {
                    _obscurePassword = !_obscurePassword;
                  }
                }),
              )
            : null,
      ),
    );
  }
}
