import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlitfilms/components/splashScreen/splash_screen.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/screens/biblioteca.dart';
import 'package:starlitfilms/screens/entrar.dart';
import 'package:starlitfilms/screens/homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final authToken = prefs.getString('authToken');



  runApp(MyApp(isLoggedIn: authToken != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        initialRoute: isLoggedIn ? '/home' : '/',
        routes: {
          '/': (context) => const SplashScreenIntro(),
          '/entrar': (context) => const Entrar(),
          '/biblioteca': (context) => Biblioteca(),
          '/home': (context) =>  HomePage(),
        },
      ),
    );
  }
}
