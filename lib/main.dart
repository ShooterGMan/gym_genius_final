import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'router/app_router.dart';
import 'providers/active_workout_provider.dart';
import 'services/image_cache_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Preload images in the background - don't block startup
  _preloadAppImages();

  runApp(const ProviderScope(child: MyApp()));
}

void _preloadAppImages() {
  // Fire and forget - images will be ready by the time user navigates
  Future.microtask(() async {
    try {
      final allImages = [
        ...ImageCacheService.categoryImages,
        ...ImageCacheService.workoutCoverImages,
        ...ImageCacheService.placeholderImages,
      ];
      
      for (final path in allImages) {
        try {
          await rootBundle.load(path);
        } catch (e) {
          // Silently skip missing images
        }
      }
      debugPrint('✅ Images preloaded');
    } catch (e) {
      debugPrint('Image preload: $e');
    }
  });
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeWorkoutProvider.notifier).restoreState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(activeWorkoutProvider.notifier).persistState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'GymGenius',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}