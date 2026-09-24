import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/theme/tokens.dart';
import 'package:starlitfilms/screens/register.dart';
import 'package:starlitfilms/screens/homepage.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true; // Estado para controlar a visibilidade da senha

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Entrance(
                      child: Image.asset('assets/logoCompleta.png', height: 200),
                    ),
                    const SizedBox(height: 8),
                    const Entrance(
                      index: 1,
                      child: Text(
                        'Que bom te ver de novo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: SC.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Entrance(
                      index: 2,
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: SC.text),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Entrance(
                      index: 3,
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        style: const TextStyle(color: SC.text),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? 'Mostrar senha' : 'Esconder senha',
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showResetPasswordDialog,
                        child: const Text('Esqueci minha senha'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Entrance(
                      index: 4,
                      child: PrimaryButton(
                        label: 'Entrar',
                        loading: _isLoading,
                        onPressed: _login,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const Cadastro()),
                      ),
                      child: RichText(
                        text: const TextSpan(
                          text: 'Ainda não tem conta? ',
                          style: TextStyle(fontFamily: 'Poppins', color: SC.textMuted),
                          children: [
                            TextSpan(
                              text: 'Criar conta',
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
    );
  }

  void _login() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email e senha não podem ser vazios'),
          backgroundColor: SC.danger,
        ),
      );
      return;
    }

    _performLogin(email, password);
  }

  Future<void> _performLogin(String email, String password) async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false).login(email, password);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: SC.danger),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showResetPasswordDialog() {
    final controller = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: SC.text),
          decoration: const InputDecoration(
            labelText: 'Email da conta',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              Navigator.of(dialogContext).pop();
              try {
                await auth.resetPassword(controller.text);
                messenger.showSnackBar(const SnackBar(
                  content: Text('Se o email existir, você receberá um link para redefinir a senha.'),
                ));
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(friendlyError(e)), backgroundColor: SC.danger),
                );
              }
            },
            child: const Text('Enviar link'),
          ),
        ],
      ),
    );
  }
}
