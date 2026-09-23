import 'package:flutter/material.dart';
import 'package:starlitfilms/models/profile.dart';

class UserAvatar extends StatelessWidget {
  final String? url;
  final double radius;

  const UserAvatar({super.key, this.url, this.radius = 20});

  factory UserAvatar.of(Profile? profile, {double radius = 20}) =>
      UserAvatar(url: profile?.avatarUrl, radius: radius);

  @override
  Widget build(BuildContext context) {
    final hasImage = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF5936B2),
      foregroundImage: hasImage ? NetworkImage(url!) : null,
      onForegroundImageError: hasImage ? (_, __) {} : null,
      child: Icon(Icons.person, size: radius * 1.2, color: Colors.white),
    );
  }
}
