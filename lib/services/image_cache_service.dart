import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final Set<String> _preloadedImages = {};

  static const List<String> categoryImages = [
    'assets/workout_covers/categories/chest.jpg',
    'assets/workout_covers/categories/back.jpg',
    'assets/workout_covers/categories/legs.jpg',
    'assets/workout_covers/categories/shoulders.jpg',
    'assets/workout_covers/categories/arms.jpg',
    'assets/workout_covers/categories/core.jpg',
    'assets/workout_covers/categories/cardio.jpg',
    'assets/workout_covers/categories/full_body.jpg',
  ];

  static const List<String> workoutCoverImages = [
    'assets/workout_covers/workouts/summer_shred.jpg',
    'assets/workout_covers/workouts/mass_builder.jpg',
    'assets/workout_covers/workouts/home_hero.jpg',
    'assets/workout_covers/workouts/strength_foundation.jpg',
    'assets/workout_covers/workouts/glute_warrior.jpg',
  ];

  static const List<String> placeholderImages = [
    'assets/placeholders/chest.jpg',
    'assets/placeholders/back.jpg',
    'assets/placeholders/legs.jpg',
    'assets/placeholders/full_body.jpg',
    'assets/placeholders/cardio.jpg',
  ];

  Future<void> preloadAllImages(BuildContext context) async {
    final allImages = [
      ...categoryImages,
      ...workoutCoverImages,
      ...placeholderImages,
    ];
    await preloadImages(context, allImages);
  }

  Future<void> preloadImages(BuildContext context, List<String> paths) async {
    for (final path in paths) {
      if (!_preloadedImages.contains(path)) {
        try {
          await rootBundle.load(path);
          if (!context.mounted) return;
          final provider = AssetImage(path);
          await precacheImage(provider, context);
          _preloadedImages.add(path);
        } catch (e) {
          // Silently skip
        }
      }
    }
  }

  static Widget cachedImage(
    String path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true, // KEY: Prevents flickering
      cacheWidth: width?.toInt(),
      cacheHeight: height?.toInt(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            placeholder ??
            Container(
              color: Colors.white10,
              child: const Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white24,
              ),
            );
      },
    );
  }

  static Widget shimmerPlaceholder({
    double? width,
    double? height,
    double borderRadius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Center(
        child: Icon(
          Icons.fitness_center,
          color: Colors.white24,
        ),
      ),
    );
  }

  static Future<bool> assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (e) {
      return false;
    }
  }
}