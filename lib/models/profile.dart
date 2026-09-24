class Profile {
  final String id;
  final String username;
  final String name;
  final String bio;
  final String? avatarUrl;

  const Profile({
    required this.id,
    required this.username,
    required this.name,
    required this.bio,
    this.avatarUrl,
  });

  String get displayName => name.isNotEmpty ? name : username;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
