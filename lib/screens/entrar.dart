import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/wave_header.dart';
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

    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
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
      backgroundColor: SC.bg,
      body: SkyBackground(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, box) {
              // Telas baixas (iPhone SE no Safari): mais espaço para os botões.
              final compact = box.maxHeight < 640;
              return Column(
                children: [
                  Expanded(
                    flex: compact ? 4 : 5,
                    child: SlideTransition(
                      position: _topAnimation,
                      child: WaveHeader(
                        waveHeight: 64,
                        child: LayoutBuilder(
                          builder: (context, c) {
                            // O logo cabe sempre no espaço acima da onda (nunca corta).
                            final top = MediaQuery.paddingOf(context).top;
                            final size = math.min(c.maxWidth * 0.78,
                                (c.maxHeight - 64 - top) * 0.92);
                            return Padding(
                              padding: EdgeInsets.only(top: top, bottom: 64),
                              child: Center(
                                child: FloatingBob(
                                  child: Image.asset(
                                    'assets/logoCompleta.png',
                                    width: size,
                                    height: size,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: compact ? 5 : 4,
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
                                const SizedBox(
                                    height:
                                        16), // Espaço entre logo pequena e o texto
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
                                const SizedBox(
                                    height:
                                        20), // Espaço entre o texto e o botão
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 360),
                                  child: PrimaryButton(
                                    label: 'Criar conta',
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => const Cadastro()),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 360),
                                  child: Pressable(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => const Login()),
                                    ),
                                    semanticLabel: 'Já tenho conta',
                                    child: Container(
                                      height: 52,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(SRadius.md),
                                        border: Border.all(
                                            color: SC.starSoft
                                                .withValues(alpha: 0.6)),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
