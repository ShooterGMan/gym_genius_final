import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/exercise_provider.dart';
import '../models/exercise.dart';
import '../theme/app_theme.dart';

class ExerciseDetailsScreen extends ConsumerStatefulWidget {
  final String exerciseId;
  const ExerciseDetailsScreen({super.key, required this.exerciseId});

  @override
  ConsumerState<ExerciseDetailsScreen> createState() =>
      _ExerciseDetailsScreenState();
}

class _ExerciseDetailsScreenState extends ConsumerState<ExerciseDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final exercisesAsyncValue = ref.watch(exercisesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: exercisesAsyncValue.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent)),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (allExercises) {
            final exercise = allExercises.firstWhere(
              (ex) => ex.id == widget.exerciseId,
              orElse: () => throw Exception('Exercise not found'),
            );

            final levelColor = exercise.level == 'beginner'
                ? Colors.greenAccent
                : (exercise.level == 'intermediate'
                    ? Colors.amberAccent
                    : Colors.redAccent);

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left,
                                  color: Colors.white, size: 32),
                              onPressed: () => context.pop(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                      SmoothCrossfadeGallery(
                        images: exercise.images,
                        height: 250,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise.name,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildBadge(exercise.category.toUpperCase(),
                                    AppColors.surface, AppColors.textSecondary),
                                const SizedBox(width: 8),
                                _buildBadge(
                                    exercise.equipment == 'body only'
                                        ? 'BODY WEIGHT'
                                        : exercise.equipment.toUpperCase(),
                                    AppColors.surface,
                                    AppColors.textSecondary),
                                const SizedBox(width: 8),
                                _buildBadge(exercise.level.toUpperCase(),
                                    AppColors.surface, levelColor),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text('MUSCLES WORKED',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...exercise.primaryMuscles.map((m) =>
                                    _buildMuscleChip(m, isPrimary: true)),
                                ...exercise.secondaryMuscles.map((m) =>
                                    _buildMuscleChip(m, isPrimary: false)),
                              ],
                            ),
                            const SizedBox(height: 32),
                            const Text('INSTRUCTIONS',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2)),
                            const SizedBox(height: 16),
                            ...exercise.instructions
                                .asMap()
                                .entries
                                .map((entry) {
                              int stepNum = entry.key + 1;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: AppColors.surface,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text('$stepNum',
                                          style: const TextStyle(
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        entry.value,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 15,
                                            height: 1.5),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border)),
      child: Text(text,
          style: TextStyle(
              color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMuscleChip(String name, {required bool isPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            isPrimary ? AppColors.accent.withOpacity(0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isPrimary
                ? AppColors.accent.withOpacity(0.5)
                : AppColors.border),
      ),
      child: Text(
        name.toUpperCase(),
        style: TextStyle(
            color: isPrimary ? AppColors.accent : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

class SmoothCrossfadeGallery extends StatefulWidget {
  final List<String> images;
  final double height;

  const SmoothCrossfadeGallery({
    super.key,
    required this.images,
    this.height = 300,
  });

  @override
  State<SmoothCrossfadeGallery> createState() => _SmoothCrossfadeGalleryState();
}

class _SmoothCrossfadeGalleryState extends State<SmoothCrossfadeGallery> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % widget.images.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    final String path =
        'assets/images/${widget.images[_currentIndex].replaceAll('/', '_')}';

    return Container(
      height: widget.height,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isIncoming = child.key == ValueKey<String>(path);
          return FadeTransition(
            opacity: isIncoming ? animation : const AlwaysStoppedAnimation(1.0),
            child: child,
          );
        },
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: Image.asset(
          path,
          key: ValueKey<String>(path),
          fit: BoxFit.contain,
          height: widget.height,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.surface,
            child: const Icon(Icons.image_not_supported,
                color: Colors.white24, size: 48),
          ),
        ),
      ),
    );
  }
}
