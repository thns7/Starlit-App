import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/models/profile.dart';
import 'package:starlitfilms/models/review.dart';
import 'package:starlitfilms/screens/review.dart';
import 'package:starlitfilms/theme/starlit_theme.dart';

final _review = Review(
  id: 1,
  content: 'Teste',
  rating: 4,
  isPublic: true,
  createdAt: DateTime(2026, 9, 20),
  author: const Profile(id: 'u', username: 'thiago', name: 'Thiago', bio: ''),
  movie: const Movie(id: 1, title: 'Filme'),
  likeCount: 3,
  commentCount: 0,
  likedByMe: false,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'https://example.supabase.co', anonKey: 'x');
  });

  // No iPhone, o app instalado na Tela de Início não tem botão "voltar" do
  // navegador: o gesto de deslizar da borda precisa funcionar em todas as telas.
  testWidgets('deslizar da borda volta da review para a página principal (iOS)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildStarlitTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReviewDetailPage(review: _review)),
              ),
              child: const Text('principal'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('principal'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ReviewDetailPage), findsOneWidget);

    await tester.dragFrom(const Offset(5, 400), const Offset(500, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ReviewDetailPage), findsNothing);
    expect(find.text('principal'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
