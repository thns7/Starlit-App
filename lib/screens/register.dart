import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
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
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/fundoLogin.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 100),
                  Image.asset(
                    'assets/logoCompleta.png',
                    width: 330,
                    height: 330,
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTextField(_nameController, 'Nome', Icons.person),
                        const SizedBox(height: 20),
                        _buildTextField(_usernameController, 'Username', Icons.account_circle, keyboardType: TextInputType.visiblePassword),
                        const SizedBox(height: 20),
                        _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 20),
                        _buildTextField(_passwordController, 'Senha', Icons.lock, isPassword: true),
                        const SizedBox(height: 20),
                        _buildTextField(_passwordConfirmController, 'Confirmar senha', Icons.lock, isPassword: true, isConfirm: true),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: 331,
                              height: 49,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        if (_validateFields()) {
                                          await _showProfilePictureDialog();
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF26174C), Color(0xFF5936B2)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: _isLoading
                                        ? const CircularProgressIndicator(
                                            strokeWidth: 3,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          )
                                        : const Text(
                                      'Criar Conta',
                                      style: TextStyle(
                                        fontFamily: "Poppins",
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) => const Login(),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOut;
                                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                                transitionDuration: const Duration(milliseconds: 500),
                              ),
                            );
                          },
                          child: RichText(
                            text: const TextSpan(
                              text: 'Já tem uma conta? ',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: "Poppins",
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                              ),
                              children: [
                                TextSpan(
                                  text: 'LOGIN',
                                  style: TextStyle(
                                    color: Color(0xFF7E56E4),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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

  Future<void> _pickAvatar(StateSetter setDialogState) async {
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
    setDialogState(() {});
  }

Future<void> _showProfilePictureDialog() async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1), // Começa fora da tela, na parte inferior
          end: Offset.zero,         // Termina no centro da tela
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut, // Efeito suave
        )),
        child: Dialog(
          backgroundColor: const Color(0xFF150B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatefulBuilder(
                  builder: (context, setDialogState) => GestureDetector(
                    onTap: () => _pickAvatar(setDialogState),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF5936B2),
                          backgroundImage:
                              _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                          child: _avatarBytes == null
                              ? const Icon(Icons.add_a_photo, color: Colors.white, size: 36)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _avatarBytes == null ? 'Escolher foto de perfil' : 'Trocar foto',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
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
                    setState(() {
                      _avatarBytes = null;
                      _avatarExtension = null;
                    });
                    Navigator.of(context).pop();
                    _registerUser();
                  },
                  child: const Text(
                    'Continuar sem foto',
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
                  onPressed: () {
                    Navigator.of(context).pop();
                    _registerUser();
                  },
                  child: const Text(
                    'Confirmar Foto',
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
            backgroundColor: const Color(0xFF150B2E),
            title: const Text('Confirme seu email', style: TextStyle(color: Colors.white)),
            content: Text(
              'Enviamos um link de confirmação para ${_emailController.text.trim()}. '
              'Depois de confirmar, faça login. Você pode adicionar sua foto em "Editar Perfil".',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Ir para o login', style: TextStyle(color: Color(0xff7E56E4))),
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
  }) {
    final obscured = isConfirm ? _obscurePasswordConfirm : _obscurePassword;
    return SizedBox(
      width: 331,
      height: 49,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        autocorrect: !isPassword && keyboardType == null,
        obscureText: isPassword ? (isConfirm ? _obscurePasswordConfirm : _obscurePassword) : false,
        style: const TextStyle(
          fontFamily: "Poppins",
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(
            fontFamily: "Poppins",
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Icon(icon, color: Colors.white),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(obscured ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70),
                  onPressed: () => setState(() {
                    if (isConfirm) {
                      _obscurePasswordConfirm = !_obscurePasswordConfirm;
                    } else {
                      _obscurePassword = !_obscurePassword;
                    }
                  }),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF5936B2).withOpacity(0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
