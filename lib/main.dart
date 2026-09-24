import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:starlitfilms/components/splashScreen/splash_screen.dart';
import 'package:starlitfilms/config.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/screens/entrar.dart';
import 'package:starlitfilms/screens/homepage.dart';
import 'package:starlitfilms/services/notification_center.dart';
import 'package:starlitfilms/theme/starlit_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<NotificationCenter>(
            create: (_) => NotificationCenter(), lazy: false),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'Starlit',
        theme: buildStarlitTheme(),
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreenIntro(),
          '/entrar': (context) => const Entrar(),
          '/home': (context) => const HomePage(),
        },
      ),
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Supabase não configurado.\n\n'
              'Rode o app com:\n'
              'flutter run --dart-define-from-file=env.json\n\n'
              '(veja env.example.json e o README)',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
