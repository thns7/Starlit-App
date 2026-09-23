import 'package:another_flutter_splash_screen/another_flutter_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:starlitfilms/screens/entrar.dart';
import 'package:starlitfilms/screens/homepage.dart';

class SplashScreenIntro extends StatefulWidget {
  const SplashScreenIntro({super.key});

  @override
  State<SplashScreenIntro> createState() => _SplashScreenIntroState();
}

class _SplashScreenIntroState extends State<SplashScreenIntro> {
  final Image fundoLogin = Image.asset('assets/fundoLogin.png');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(fundoLogin.image, context);
  }

  @override
  Widget build(BuildContext context) {
    // A sessão é restaurada automaticamente pelo supabase_flutter.
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;

    return FlutterSplashScreen.scale(
      backgroundColor: const Color.fromARGB(255, 48, 24, 112),
      childWidget: SizedBox(
        height: 300,
        child: Image.asset('assets/logoCompleta.png'),
      ),
      duration: const Duration(milliseconds: 2500),
      animationDuration: const Duration(milliseconds: 1250),
      nextScreen: isLoggedIn ? const HomePage() : const Entrar(),
    );
  }
}
