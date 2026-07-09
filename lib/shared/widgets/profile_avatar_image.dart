import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_fonts.dart';
import '../../config/dashboard_theme.dart';
import '../../services/auth_service.dart';

/// Driver profile photo from API, or initials when unavailable.
class ProfileAvatarImage extends StatelessWidget {
  const ProfileAvatarImage({
    super.key,
    required this.size,
    this.avatarUrl,
    this.displayName,
    this.fit = BoxFit.cover,
  });

  final double size;
  final String? avatarUrl;
  final String? displayName;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = avatarUrl;
    final initials = AuthService.initialsFromName(displayName);

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      return Image.network(
        resolvedUrl,
        key: ValueKey(resolvedUrl),
        width: size,
        height: size,
        fit: fit,
        headers: AuthService.storageImageHeaders,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return ProfileAvatarPlaceholder(
            size: size,
            initials: initials,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return ProfileAvatarPlaceholder(
            size: size,
            initials: initials,
          );
        },
      );
    }

    return ProfileAvatarPlaceholder(
      size: size,
      initials: initials,
    );
  }
}

class ProfileAvatarPlaceholder extends StatelessWidget {
  const ProfileAvatarPlaceholder({
    super.key,
    required this.size,
    required this.initials,
  });

  final double size;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);

    return Container(
      width: size,
      height: size,
      color: dashboard.pillBackground,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: AppFonts.satoshi,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: AppColors.loginButton,
          height: 1,
        ),
      ),
    );
  }
}
