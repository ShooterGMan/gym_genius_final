import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/tracker_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../models/exercise.dart';
import '../theme/app_theme.dart';

class WorkoutHistoryDetailsScreen extends ConsumerWidget {
  final String workoutId;
  const WorkoutHistoryDetailsScreen({super.key, required this.workoutId});

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          title: const Text(
            'DELETE WORKOUT?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          content: const Text(
            'This will permanently delete this completed session from your history and stats. This action cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(context); // Pop dialog
                await ref.read(trackerProvider.notifier).deleteWorkout(workoutId);
                if (context.mounted) {
                  context.pop(); // Pop screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Workout deleted.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              child: const Text(
                'DELETE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackerState = ref.watch(trackerProvider);
    final allExercises = ref.watch(exercisesProvider).value ?? [];

    // Find the workout by ID
    final workout = trackerState.history.firstWhere(
      (w) => w.id == workoutId,
      orElse: () {
        // If not found, return a default empty workout (shouldn't happen)
        return CompletedWorkout(
          id: workoutId,
          date: DateTime.now(),
          durationSeconds: 0,
          totalVolume: 0,
          routine: [],
        );
      },
    );

    // Calculate total sets
    double totalSets = 0;
    for (final ex in workout.routine) {
      totalSets += ex.sets.length;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("SESSION DETAILS"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
            onPressed: () => _showDeleteConfirmDialog(context, ref),
          ),
        ],
      ),
      body: workout.routine.isEmpty
          ? const Center(
              child: Text(
                "No exercises in this workout.",
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Workout Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${workout.date.day}/${workout.date.month}/${workout.date.year}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatWeekday(workout.date),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Stats
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.timer,
                                  color: AppColors.accent, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                "${workout.durationSeconds ~/ 60} min",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.fitness_center,
                                  color: AppColors.accent, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                "${workout.totalVolume.toInt()} ${ref.watch(settingsProvider).weightUnit}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${workout.routine.length} exercises • ${totalSets.toInt()} sets",
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Exercise List
                ...workout.routine.map((liveEx) {
                  // Find the exercise info
                  final ex = allExercises.firstWhere(
                    (e) => e.id == liveEx.exerciseId,
                    orElse: () => Exercise(
                      id: liveEx.exerciseId,
                      name: liveEx.exerciseId,
                      equipment: '',
                      level: '',
                      primaryMuscles: [],
                      secondaryMuscles: [],
                      category: '',
                      images: [],
                      instructions: [],
                    ),
                  );

                  return _buildExerciseBlock(context, ref, liveEx, ex);
                }),
              ],
            ),
    );
  }

  String _formatWeekday(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return weekdays[date.weekday - 1];
  }

  Widget _buildExerciseBlock(
    BuildContext context,
    WidgetRef ref,
    WorkoutExerciseLive liveEx,
    Exercise ex,
  ) {
    // Determine labels based on log mode
    String unit1 = ref.read(settingsProvider).weightUnit.toUpperCase();
    String unit2 = "REPS";
    if (liveEx.logMode == LogMode.repsOnly) {
      unit1 = "";
    } else if (liveEx.logMode == LogMode.timeAndReps) {
      unit1 = "TIME";
      unit2 = "REPS";
    } else if (liveEx.logMode == LogMode.timeAndDistance) {
      unit1 = "TIME";
      unit2 = "KM";
    }

    // Calculate volume for this exercise
    double exerciseVolume = 0;
    int completedSets = 0;
    for (final set in liveEx.sets) {
      if (set.isCompleted) {
        completedSets++;
        if (liveEx.tracksWeight) {
          exerciseVolume += (double.tryParse(set.weight) ?? 0) *
              (double.tryParse(set.reps) ?? 0);
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise Header
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/library/exercise/${ex.id}'),
                  child: Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ex.images.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/images/${ex.images[0].replaceAll('/', '_')}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.fitness_center,
                                          color: Colors.white24),
                                ),
                              )
                            : const Icon(Icons.fitness_center,
                                color: Colors.white24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.name,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              liveEx.tracksWeight
                                  ? "$completedSets sets • ${exerciseVolume.toInt()} ${unit1.toLowerCase()} volume"
                                  : "$completedSets sets",
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
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Column Headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 30,
                  child: Text(
                    "SET",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (unit1.isNotEmpty)
                Expanded(
                  child: Text(
                    unit1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    unit2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Set Rows
          ...liveEx.sets.asMap().entries.map((entry) {
            final set = entry.value;
            final setIndex = entry.key + 1;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: set.isCompleted
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      set.type == SetType.normal
                          ? "$setIndex"
                          : "$setIndex${set.type.marker}",
                      style: TextStyle(
                        color: set.isCompleted
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (unit1.isNotEmpty)
                  Expanded(
                    child: Text(
                      set.isCompleted
                          ? (set.weight.isEmpty ? "-" : set.weight)
                          : "SKIP",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: set.isCompleted ? Colors.white : Colors.white24,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      set.isCompleted
                          // Older reps-only logs stored reps in the weight field.
                          ? (set.reps.isNotEmpty
                                  ? set.reps
                                  : (unit1.isEmpty && set.weight.isNotEmpty
                                      ? set.weight
                                      : "-")) +
                              (set.rpe != null
                                  ? " @${set.rpe! % 1 == 0 ? set.rpe!.toInt() : set.rpe}"
                                  : "")
                          : "SKIP",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: set.isCompleted ? Colors.white : Colors.white24,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Icon(
                      set.isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color:
                          set.isCompleted ? AppColors.accent : Colors.white24,
                      size: 20,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
