import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tracker_provider.dart';
import '../providers/exercise_provider.dart';
import '../models/exercise.dart';

class PersonalRecord {
  final String exerciseId;
  final String exerciseName;
  final double weight;
  final int reps;
  final DateTime date;
  final String category; // 'weight', 'reps', 'volume'

  PersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.date,
    required this.category,
  });

  double get volume => weight * reps;
  String get formattedDate => '${date.day}/${date.month}/${date.year}';
}

class PRState {
  final Map<String, PersonalRecord> heaviestWeight; // exerciseId -> PR
  final Map<String, PersonalRecord> mostReps; // exerciseId -> PR
  final Map<String, PersonalRecord> highestVolume; // exerciseId -> PR
  final List<PersonalRecord> recentPRs; // Last 10 PRs
  final bool isLoading;

  PRState({
    this.heaviestWeight = const {},
    this.mostReps = const {},
    this.highestVolume = const {},
    this.recentPRs = const [],
    this.isLoading = false,
  });
}

final prTrackerProvider = Provider<PRState>((ref) {
  final trackerState = ref.watch(trackerProvider);
  final exercises = ref.watch(exercisesProvider).value ?? [];

  return _calculatePRs(trackerState.history, exercises);
});

PRState _calculatePRs(List<CompletedWorkout> history, List<Exercise> exercises) {
  final Map<String, PersonalRecord> heaviestWeight = {};
  final Map<String, PersonalRecord> mostReps = {};
  final Map<String, PersonalRecord> highestVolume = {};
  final List<PersonalRecord> allPRs = [];

  for (final workout in history) {
    for (final liveEx in workout.routine) {
      final exercise = exercises.firstWhere(
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

      for (final set in liveEx.sets) {
        if (!set.isCompleted) continue;
        
        final weight = double.tryParse(set.weight) ?? 0;
        final reps = int.tryParse(set.reps) ?? 0;
        if (weight <= 0 || reps <= 0) continue;

        final volume = weight * reps;

        // Check heaviest weight
        if (!heaviestWeight.containsKey(exercise.id) || weight > heaviestWeight[exercise.id]!.weight) {
          final pr = PersonalRecord(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            weight: weight,
            reps: reps,
            date: workout.date,
            category: 'weight',
          );
          heaviestWeight[exercise.id] = pr;
          allPRs.add(pr);
        }

        // Check most reps
        if (!mostReps.containsKey(exercise.id) || reps > mostReps[exercise.id]!.reps) {
          final pr = PersonalRecord(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            weight: weight,
            reps: reps,
            date: workout.date,
            category: 'reps',
          );
          mostReps[exercise.id] = pr;
          allPRs.add(pr);
        }

        // Check highest volume
        if (!highestVolume.containsKey(exercise.id) || volume > highestVolume[exercise.id]!.volume) {
          final pr = PersonalRecord(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            weight: weight,
            reps: reps,
            date: workout.date,
            category: 'volume',
          );
          highestVolume[exercise.id] = pr;
          allPRs.add(pr);
        }
      }
    }
  }

  // Sort PRs by date (most recent first) and take last 10
  allPRs.sort((a, b) => b.date.compareTo(a.date));
  final recentPRs = allPRs.take(10).toList();

  return PRState(
    heaviestWeight: heaviestWeight,
    mostReps: mostReps,
    highestVolume: highestVolume,
    recentPRs: recentPRs,
  );
}