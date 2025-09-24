import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/wallpaper_service.dart';

class BackgroundGradient extends StatelessWidget {
  final Widget child;

  const BackgroundGradient({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WallpaperService>(
      builder: (context, wallpaperService, _) {
        // Check if wallpaper is enabled and file exists
        final wallpaperFile = wallpaperService.getWallpaperFile();

        if (wallpaperFile != null) {
          return FutureBuilder<bool>(
            future: wallpaperFile.exists(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  snapshot.data != true) {
                // Show gradient while loading or if file doesn't exist
                return _buildGradientBackground();
              }

              return _buildWallpaperBackground(wallpaperFile);
            },
          );
        }

        // Default gradient background
        return _buildGradientBackground();
      },
      child: child,
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryDark, AppTheme.secondaryDark],
        ),
      ),
      child: child,
    );
  }

  Widget _buildWallpaperBackground(File wallpaperFile) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: FileImage(wallpaperFile),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(
              0.3,
            ), // Add overlay for better text readability
            BlendMode.darken,
          ),
        ),
      ),
      child: child,
    );
  }
}
