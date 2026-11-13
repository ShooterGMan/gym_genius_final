import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/program_provider.dart';
import '../providers/active_workout_provider.dart';
import '../models/program.dart';
import '../theme/app_theme.dart';

class RoutineSelectorBottomSheet extends ConsumerWidget {
  final String exerciseId;
  final String exerciseName;

  const RoutineSelectorBottomSheet({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programState = ref.watch(programProvider);
    final activeState = ref.watch(activeWorkoutProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ADD TO ROUTINE",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            exerciseName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          _buildOption(
            context,
            icon: Icons.add_rounded,
            title: "Create New Program",
            subtitle: "Build a new plan with this exercise",
            onTap: () {
              Navigator.pop(context);
              context.push('/programs/create?initialExerciseId=$exerciseId');
            },
          ),
          const Divider(color: Colors.white10, height: 32),
          if (activeState.isActive)
            _buildOption(
              context,
              icon: Icons.bolt,
              title: "Add to Live Session",
              subtitle: "Include in current workout",
              onTap: () {
                ref
                    .read(activeWorkoutProvider.notifier)
                    .addExercise(exerciseId);
                Navigator.pop(context);
              },
            ),
          if (programState.customPrograms.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 12),
              child: Text(
                "YOUR PROGRAMS",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...programState.customPrograms.expand((program) {
              return program.routines.map((routine) {
                return _buildOption(
                  context,
                  icon: Icons.folder_copy_outlined,
                  title: routine.name,
                  subtitle: program.name,
                  onTap: () {
                    final updatedRoutines = program.routines.map((r) {
                      if (r.id == routine.id) {
                        return WorkoutRoutine(
                          id: r.id,
                          name: r.name,
                          exercises: [
                            ...r.exercises,
                            PlannedExercise(exerciseId: exerciseId),
                          ],
                        );
                      }
                      return r;
                    }).toList();

                    final updatedProgram =
                        program.copyWith(routines: updatedRoutines);
                    ref
                        .read(programProvider.notifier)
                        .updateProgram(updatedProgram);

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Added to ${routine.name}',
                            style: const TextStyle(color: Colors.black)),
                        backgroundColor: AppColors.accent,
                      ),
                    );
                  },
                );
              });
            }),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
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
