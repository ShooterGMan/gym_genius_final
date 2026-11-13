import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/program.dart';
import '../providers/active_workout_provider.dart';
import '../theme/app_theme.dart';

/// Single entry point for starting a workout from anywhere in the app.
///
/// If a session is already running the user is asked whether to resume it or
/// discard it, instead of it being silently overwritten.
Future<void> launchWorkout(
  BuildContext context,
  WidgetRef ref, {
  WorkoutRoutine? routine,
  VoidCallback? onStarted,
}) async {
  final active = ref.read(activeWorkoutProvider);

  if (active.isActive) {
    final done = active.completedSetCount;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Workout in progress',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          done > 0
              ? 'You have $done completed set${done == 1 ? '' : 's'} in your current session. Starting a new workout will discard it.'
              : 'You already have a session running. Starting a new workout will discard it.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            child: const Text('Discard & start new',
                style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(ctx, 'resume'),
            child: const Text('Resume current',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (choice == 'resume') {
      context.push('/workout');
      return;
    }
    if (choice != 'replace') return;
  }

  HapticFeedback.mediumImpact();
  final notifier = ref.read(activeWorkoutProvider.notifier);
  if (routine != null) {
    notifier.startRoutine(routine);
  } else {
    notifier.startEmptyWorkout();
  }
  onStarted?.call();
  if (context.mounted) context.push('/workout');
}
