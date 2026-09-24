import 'package:flutter/material.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/screens/login.dart';
import 'package:starlitfilms/theme/tokens.dart';
import 'package:starlitfilms/screens/register.dart';

class Entrar extends StatefulWidget {
  const Entrar({super.key});

  @override
  State<Entrar> createState() => _EntrarState();
}

class _EntrarState extends State<Entrar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _contentAnimation;
  late Animation<Offset> _topAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _contentAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _topAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/fundoLogin.png'),
              fit: BoxFit.cover, // Ajuste se necessário
            ),
          ),
          child: Column(
            children: [
              Expanded(
                flex: 5,
                child: SlideTransition(
                  position: _topAnimation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/detalheEntrarWaves.png',
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Image.asset(
                        'assets/logoCompleta.png',
                        width: 330,
                        height: 330,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _contentAnimation,
                      child: SingleChildScrollView(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/logoSmall.png',
                              height: 50,
                              width: 50,
                            ),
                             const SizedBox(height: 16), // Espaço entre logo pequena e o texto
                          const Text(
                            "Descubra o mundo do cinema: compartilhe suas opiniões e encontre novos filmes para amar.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: SC.textMuted,
                              fontSize: 14.5,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20), // Espaço entre o texto e o botão
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: PrimaryButton(
                                label: 'Criar conta',
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const Cadastro()),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: Pressable(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const Login()),
                                ),
                                semanticLabel: 'Já tenho conta',
                                child: Container(
                                  height: 52,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(SRadius.md),
                                    border: Border.all(color: SC.starSoft.withValues(alpha: 0.6)),
                                  ),
                                  child: const Text(
                                    'Já tenho conta',
                                    style: TextStyle(
                                      color: SC.text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}
