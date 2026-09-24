import 'package:flutter/material.dart';
import 'package:starlitfilms/models/profile.dart';
import 'package:starlitfilms/theme/tokens.dart';

class UserAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final bool ring;

  const UserAvatar({super.key, this.url, this.radius = 20, this.ring = false});

  factory UserAvatar.of(Profile? profile, {double radius = 20, bool ring = false}) =>
      UserAvatar(url: profile?.avatarUrl, radius: radius, ring: ring);

  @override
  Widget build(BuildContext context) {
    final hasImage = url != null && url!.isNotEmpty;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: SC.surfaceHigher,
      foregroundImage: hasImage ? NetworkImage(url!) : null,
      onForegroundImageError: hasImage ? (_, __) {} : null,
      child: Icon(Icons.person_rounded, size: radius * 1.1, color: SC.textMuted),
    );
    if (!ring) return avatar;
    return Container(
      padding: EdgeInsets.all(radius > 30 ? 3 : 2),
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: SC.heroGradient),
      child: Container(
        padding: EdgeInsets.all(radius > 30 ? 3 : 2),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: SC.bg),
        child: avatar,
      ),
    );
  }
}
