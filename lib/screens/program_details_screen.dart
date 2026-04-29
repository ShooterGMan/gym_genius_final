import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/program_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../models/exercise.dart';
import '../models/program.dart';
import '../theme/app_theme.dart';

class ProgramDetailsScreen extends ConsumerWidget {
  final String programId;
  const ProgramDetailsScreen({super.key, required this.programId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programState = ref.watch(programProvider);
    final notifier = ref.read(programProvider.notifier);
    final activeNotifier = ref.read(activeWorkoutProvider.notifier);
    final allExercises = ref.watch(exercisesProvider).value ?? [];

    final program = programState.allPrograms.firstWhere(
      (p) => p.id == programId,
      orElse: () => Program(
        id: '0',
        name: 'Not Found',
        description: '',
        coverImage: '',
        difficulty: Difficulty.intermediate,
        categories: [],
        equipment: [],
        routines: [],
      ),
    );

    if (program.id == '0') {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child:
              Text("Program not found", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final bool isCustom = program.isCustom;
    final bool isActive = programState.activeProgramId == program.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppColors.background,
                leading: IconButton(
                  icon: const Icon(Icons.chevron_left,
                      size: 32, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  if (isCustom)
                    IconButton(
                      icon: const Icon(Icons.edit_note,
                          color: AppColors.accent, size: 28),
                      onPressed: () =>
                          context.push('/programs/create?id=${program.id}'),
                    ),
                  const SizedBox(width: 12),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        program.displayImage,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.surface,
                          child: const Icon(Icons.fitness_center,
                              size: 48, color: Colors.white24),
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xFF09090B), Colors.transparent],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 32,
                        left: 24,
                        right: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: program.difficultyColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                program.difficultyLabel.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              program.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                              ),
                            ),
                            Text(
                              program.categoriesLabel,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final routine = program.routines[index];
                      final bool isNextOnDashboard =
                          isActive && programState.currentRoutineIndex == index;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isNextOnDashboard
                                ? AppColors.accent.withOpacity(0.3)
                                : Colors.white10,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "${index + 1}",
                                      style: const TextStyle(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    routine.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    activeNotifier.startEmptyWorkout();
                                    for (var exercise in routine.exercises) {
                                      activeNotifier.addExercise(
                                        exercise.exerciseId,
                                        setsCount: exercise.sets,
                                        repsHint: exercise.reps,
                                      );
                                    }
                                    notifier.setCurrentRoutineIndex(index);
                                    context.push('/workout');
                                  },
                                  icon: const Icon(
                                    Icons.play_circle_fill,
                                    color: AppColors.accent,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                            if (isNextOnDashboard)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  "UP NEXT ON DASHBOARD",
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                            ...routine.exercises.map((planned) {
                              // Find exercise with fallback
                              Exercise exercise;
                              try {
                                exercise = allExercises.firstWhere(
                                    (e) => e.id == planned.exerciseId);
                              } catch (e) {
                                // Create a friendly display name from the ID
                                final displayName = planned.exerciseId
                                    .split('_')
                                    .map((word) => word.isNotEmpty
                                        ? word[0].toUpperCase() +
                                            word.substring(1)
                                        : '')
                                    .join(' ');

                                exercise = Exercise(
                                  id: planned.exerciseId,
                                  name: displayName.isNotEmpty
                                      ? displayName
                                      : 'Exercise',
                                  equipment: "",
                                  level: "",
                                  primaryMuscles: [],
                                  secondaryMuscles: [],
                                  category: "",
                                  images: [],
                                  instructions: [
                                    "Exercise details coming soon."
                                  ],
                                );
                              }
                              return _buildExerciseRow(
                                  context, exercise, planned);
                            }).toList(),
                          ],
                        ),
                      );
                    },
                    childCount: program.routines.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.background,
                    AppColors.background.withOpacity(0),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isActive ? AppColors.surface : AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isActive
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        notifier.setActiveProgram(program.id);
                        context.go('/dashboard');
                      },
                child: Text(
                  isActive ? "ACTIVE PROGRAM" : "SET AS ACTIVE PROGRAM",
                  style: TextStyle(
                    color: isActive ? Colors.white24 : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(
      BuildContext context, Exercise exercise, PlannedExercise planned) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        // Only navigate if the exercise has valid data
        if (exercise.instructions.isNotEmpty ||
            exercise.primaryMuscles.isNotEmpty) {
          context.push('/library/exercise/${exercise.id}');
        } else {
          // Show a snackbar for placeholder exercises
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${exercise.name} details coming soon!'),
              backgroundColor: AppColors.accent,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Exercise Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 50,
                height: 50,
                child: exercise.images.isNotEmpty
                    ? Image.asset(
                        'assets/images/${exercise.images[0].replaceAll('/', '_')}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.background,
                          child: const Icon(Icons.fitness_center,
                              color: Colors.white24, size: 24),
                        ),
                      )
                    : Container(
                        color: AppColors.background,
                        child: const Icon(Icons.fitness_center,
                            color: Colors.white24, size: 24),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (exercise.primaryMuscles.isNotEmpty)
                    Text(
                      exercise.primaryMuscles.join(', '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${planned.sets} × ${planned.reps}",
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Colors.white24,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
