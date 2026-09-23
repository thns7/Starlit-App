import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:starlitfilms/models/profile.dart';
import 'package:starlitfilms/services/supabase_service.dart';

/// Resultado do cadastro: se o projeto exige confirmação de email,
/// o usuário ainda não está logado ao final do signUp.
enum RegisterResult { loggedIn, needsEmailConfirmation }

class AuthProvider with ChangeNotifier {
  final SupabaseService _service = SupabaseService.instance;
  StreamSubscription<AuthState>? _authSub;

  Profile? _profile;

  AuthProvider() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _profile = null;
        notifyListeners();
      } else if (data.session != null && _profile == null) {
        loadProfile();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // === Getters usados pelas telas ===
  User? get user => Supabase.instance.client.auth.currentUser;
  bool get isAuthenticated => user != null;
  Profile? get profile => _profile;
  String? get userId => user?.id;
  String? get email => user?.email;
  String? get nome => _profile?.name;
  String? get username => _profile?.username;
  String? get descricao => _profile?.bio;
  String? get avatar => _profile?.avatarUrl;

  Future<void> loadProfile() async {
    final id = userId;
    if (id == null) return;
    try {
      _profile = await _service.fetchProfile(id);
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar perfil: $e');
    }
  }

  // === Autenticação ===
  Future<void> login(String email, String password) async {
    try {
      await Supabase.instance.client.auth
          .signInWithPassword(email: email.trim(), password: password);
    } on AuthException catch (e) {
      throw friendlyAuthError(e);
    }
    await loadProfile();
  }

  Future<RegisterResult> register({
    required String nome,
    required String username,
    required String email,
    required String password,
    Uint8List? avatarBytes,
    String? avatarExtension,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (!await _service.isUsernameAvailable(normalized)) {
      throw 'Esse username já está em uso.';
    }

    final AuthResponse response;
    try {
      response = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'username': normalized, 'name': nome.trim()},
      );
    } on AuthException catch (e) {
      throw friendlyAuthError(e);
    }

    if (response.session == null) {
      return RegisterResult.needsEmailConfirmation;
    }

    if (avatarBytes != null) {
      try {
        final url =
            await _service.uploadAvatar(avatarBytes, avatarExtension ?? 'jpg');
        await _service.updateProfile(
          name: nome.trim(),
          username: normalized,
          bio: '',
          avatarUrl: url,
        );
      } catch (e) {
        debugPrint('Erro ao enviar avatar: $e');
      }
    }
    await loadProfile();
    return RegisterResult.loggedIn;
  }

  Future<void> resetPassword(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw friendlyAuthError(e);
    }
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    _profile = null;
    notifyListeners();
  }

  // === Perfil ===
  Future<void> updateProfile({
    required String nome,
    required String username,
    required String descricao,
    Uint8List? avatarBytes,
    String? avatarExtension,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (normalized != _profile?.username &&
        !await _service.isUsernameAvailable(normalized)) {
      throw 'Esse username já está em uso.';
    }
    String? avatarUrl;
    if (avatarBytes != null) {
      avatarUrl =
          await _service.uploadAvatar(avatarBytes, avatarExtension ?? 'jpg');
    }
    _profile = await _service.updateProfile(
      name: nome.trim(),
      username: normalized,
      bio: descricao.trim(),
      avatarUrl: avatarUrl,
    );
    notifyListeners();
  }
}

/// Traduz os erros mais comuns do Supabase Auth.
String friendlyAuthError(AuthException e) {
  final msg = e.message.toLowerCase();
  if (msg.contains('invalid login credentials')) {
    return 'Email ou senha incorretos.';
  }
  if (msg.contains('email not confirmed')) {
    return 'Confirme seu email antes de entrar (veja sua caixa de entrada).';
  }
  if (msg.contains('already registered') || msg.contains('already been registered')) {
    return 'Já existe uma conta com esse email.';
  }
  if (msg.contains('password')) {
    return 'Senha inválida: use pelo menos 8 caracteres.';
  }
  if (msg.contains('rate limit') || msg.contains('too many')) {
    return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
  }
  if (msg.contains('invalid') && msg.contains('email')) {
    return 'Email inválido.';
  }
  return e.message;
}

/// Mensagem legível para qualquer erro vindo do Supabase.
String friendlyError(Object e) {
  if (e is String) return e;
  if (e is AuthException) return friendlyAuthError(e);
  if (e is PostgrestException) {
    if (e.code == '23505') return 'Esse registro já existe.';
    if (e.code == '23514') return 'Dados inválidos. Verifique os campos.';
    if (e.code == '42501') return 'Você não tem permissão para isso.';
    return e.message;
  }
  if (e is StorageException) return 'Erro ao enviar imagem: ${e.message}';
  return 'Algo deu errado. Verifique sua conexão e tente novamente.';
}
