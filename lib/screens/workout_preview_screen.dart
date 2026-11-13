import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/program_provider.dart';
import '../providers/exercise_provider.dart';
import '../models/program.dart';
import '../models/exercise.dart';
import '../theme/app_theme.dart';

class WorkoutPreviewScreen extends ConsumerWidget {
  final String programId;
  const WorkoutPreviewScreen({super.key, required this.programId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programState = ref.watch(programProvider);
    final exercises = ref.watch(exercisesProvider).value ?? [];

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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'Program not found',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final isImported = programState.customPrograms.any(
      (p) =>
          p.importedFrom == programId ||
          (p.name == program.name && p.isImported),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, program),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildOverview(program),
                    const SizedBox(height: 32),
                    _buildEquipmentList(program),
                    const SizedBox(height: 32),
                    _buildRoutinesList(context, program, exercises),
                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),
          _buildBottomBar(context, ref, program, isImported),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Program program) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => context.pop(),
      ),
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
                    size: 64, color: Colors.white24),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.8),
                    AppColors.background,
                  ],
                  stops: const [0.6, 0.8, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
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
    );
  }

  Widget _buildOverview(Program program) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            program.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(
                Icons.calendar_today,
                "${program.totalWorkouts} Days",
                "Per Week",
              ),
              _buildStat(
                Icons.timer,
                program.estimatedDuration,
                "Avg Duration",
              ),
              _buildStat(
                Icons.trending_up,
                "${program.estimatedWeeks} Weeks",
                "Duration",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentList(Program program) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "EQUIPMENT NEEDED",
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: program.equipment.map((eq) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                eq,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRoutinesList(
      BuildContext context, Program program, List<Exercise> exercises) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "WORKOUT ROUTINES",
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        ...program.routines.asMap().entries.map((entry) {
          final index = entry.key;
          final routine = entry.value;
          return _buildRoutineCard(context, routine, index, exercises);
        }),
      ],
    );
  }

  Widget _buildRoutineCard(BuildContext context, WorkoutRoutine routine,
      int index, List<Exercise> exercises) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
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
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${routine.exercises.length} exercises • ${routine.totalSets} sets",
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...routine.exercises.map((planned) {
            // Find exercise with fallback
            Exercise exercise;
            try {
              exercise =
                  exercises.firstWhere((e) => e.id == planned.exerciseId);
            } catch (e) {
              // Create a friendly display name from the ID
              final displayName = planned.exerciseId
                  .split('_')
                  .map((word) => word[0].toUpperCase() + word.substring(1))
                  .join(' ');

              exercise = Exercise(
                id: planned.exerciseId,
                name: displayName,
                equipment: "",
                level: "",
                primaryMuscles: [],
                secondaryMuscles: [],
                category: "",
                images: [],
                instructions: ["Exercise details coming soon."],
              );
            }
            return _buildExerciseRow(context, exercise, planned);
          }),
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
                color: AppColors.accent.withValues(alpha: 0.1),
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

  Widget _buildBottomBar(
      BuildContext context, WidgetRef ref, Program program, bool isImported) {
    return Positioned(
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
              AppColors.background.withValues(alpha: 0.8),
              Colors.transparent,
            ],
            stops: const [0.6, 0.8, 1.0],
          ),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isImported ? AppColors.surface : AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: isImported ? 0 : 4,
          ),
          onPressed: isImported
              ? null
              : () async {
                  HapticFeedback.mediumImpact();

                  try {
                    await ref
                        .read(programProvider.notifier)
                        .importProgram(program.id);

                    if (context.mounted) {
                      final router = GoRouter.of(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('${program.name} added to My Programs!'),
                          backgroundColor: AppColors.accent,
                          duration: const Duration(seconds: 3),
                          action: SnackBarAction(
                            label: 'VIEW',
                            textColor: Colors.black,
                            onPressed: () {
                              router.go('/programs');
                            },
                          ),
                        ),
                      );
                      router.pop();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error importing program: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
          child: Text(
            isImported ? "ALREADY IN MY PROGRAMS" : "ADD TO MY PROGRAMS",
            style: TextStyle(
              color: isImported ? Colors.white38 : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
