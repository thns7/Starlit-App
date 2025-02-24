import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  final String baseUrl = "https://085f9066-c8dd-482c-9586-8323a28d1a04-00-12tnm9gw2ncin.picard.replit.dev";

  Uri _createUri(String path) {
    return Uri.parse('$baseUrl$path');
  }

  // Registro de um novo usuário
  Future<void> register(String nome, String email, String password, String avatar, String username) async {
    final uri = _createUri('/user/register');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': nome,
        'email': email,
        'password': password,
        'avatar': avatar,
        'username': username,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  // Login do usuário que também retorna o corpo da resposta
  Future<String> login(String email, String password) async {
    final url = _createUri("/user/login");

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  // Verificação de autenticação para validar o token
  Future<Map<String, dynamic>> verifyAuthentication(String token) async {
    final url = _createUri("/user/verify-auth");

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'loggedToken': token}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to verify authentication: ${response.body}');
    }
  }


  

  
  Future<void> updateUserDetails(String email, String nome, String avatar, String descricao, String username) async {
    final url = _createUri("/user/update");

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer YOUR_TOKEN_HERE',
      },
      body: json.encode({
        'email': email,
        'name': nome,
        'avatar': avatar,
        'description': descricao,
        'username': username,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update user details: ${response.body}');
    }
  }
  

  // Busca a lista de amigos de um usuário
  Future<List<dynamic>> fetchFriends(String username) async {
    final uri = _createUri('/user/amigos');

    print('pra Hel${username}');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({'username': username}),
    );

    print('bakfsa $response.body');

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch friends: ${response.body}');
    }
  }
  Future<List<dynamic>> fetchReviews(String username) async {
    final uri = _createUri('/user/reviews');

    print('pra Hel${username}');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({'username': username}),
    );

    print('bakfsa $response.body');

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch reviews: ${response.body}');
    }
  }

  // Adiciona um novo amigo à lista do usuário
  Future<void> addFriend(String email, String emailFriend, String token) async {
    final uri = _createUri('/friends/adicionar');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'email': email,
        'emailFriend': emailFriend,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add friend: ${response.body}');
    }
  }

  // Remove um amigo da lista do usuário
  Future<void> removeFriend(String email, String emailFriend, String token) async {
    final uri = _createUri('/friends/remover');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'email': email,
        'emailFriend': emailFriend,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove friend: ${response.body}');
    }
  }

  // Método para publicar uma review
  Future<void> publishReview(String userEmail, String reviewText, int rating, String token) async {
    final url = _createUri('/Review');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'userEmail': userEmail,
        'reviewText': reviewText,
        'rating': rating,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to publish review: ${response.body}');
    }
  }

  // Método para apagar uma review
  Future<void> deleteReview(String reviewId, String token) async {
    final url = _createUri('/reviews/$reviewId');

    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete review: ${response.body}');
    }
  }

  // Método para editar uma review
  Future<void> editReview(String reviewId, String reviewText, int rating, String token) async {
    final url = _createUri('/reviews/$reviewId');

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'reviewText': reviewText,
        'rating': rating,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to edit review: ${response.body}');
    }
  }

  

  // Método para buscar filmes
  Future<List<dynamic>> fetchFilmes(String token) async {
    final uri = _createUri('/movies');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch filmes: ${response.body}');
    }
  }

  // Método para buscar todas as reviews
// Método para buscar todas as reviews
Future<List<dynamic>> fetchAllReviews() async {
  final uri = _createUri('/reviews'); // Supondo que você tenha uma rota para isso

  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    // Verifique se a resposta contém a estrutura esperada
    if (data is List) {
      return data; // Retorna a lista de reviews
    } else {
      throw Exception('Formato de resposta inesperado: ${response.body}');
    }
  } else {
    throw Exception('Failed to fetch all reviews: ${response.body}');
  }
}
 
   Future<List<dynamic>> fetchComments(String reviewId, String token) async {
    final url = _createUri('/get-comentarios-por-id?id=$reviewId'); // Rota para buscar comentários por ID

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch comments: ${response.body}');
    }
  }

  // Método para comentar uma review
  Future<void> commentReview(String reviewId, String commentText, String token) async {
    final url = _createUri('/send-comment-review'); // Rota para enviar um comentário

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'reviewId': reviewId,
        'commentText': commentText,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to comment on review: ${response.body}');
    }
  }
}
