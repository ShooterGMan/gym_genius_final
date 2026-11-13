import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/tracker_provider.dart';
import '../providers/active_workout_provider.dart';
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

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'weight': weight,
        'reps': reps,
        'date': date.toIso8601String(),
        'category': category,
      };

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
        exerciseId: json['exerciseId'] ?? '',
        exerciseName: json['exerciseName'] ?? '',
        weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
        reps: json['reps'] ?? 0,
        date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
        category: json['category'] ?? 'weight',
      );
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

class ManualPRsNotifier extends Notifier<List<PersonalRecord>> {
  static const _storageKey = 'manual_prs_v1';

  @override
  List<PersonalRecord> build() {
    _loadManualPRs();
    return const [];
  }

  Future<void> _loadManualPRs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null) {
      try {
        final List<dynamic> list = json.decode(jsonStr);
        state = list.map((item) => PersonalRecord.fromJson(item)).toList();
      } catch (e) {
        debugPrint('Error loading manual PRs: $e');
      }
    }
  }

  Future<void> addManualPR(PersonalRecord pr) async {
    final updated = [...state, pr];
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(updated.map((x) => x.toJson()).toList()));
  }

  Future<void> clearAll() async {
    state = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> deleteManualPR(PersonalRecord pr) async {
    final updated = state.where((item) => !(item.exerciseId == pr.exerciseId && item.category == pr.category && item.date == pr.date)).toList();
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(updated.map((x) => x.toJson()).toList()));
  }
}

final manualPRsProvider = NotifierProvider<ManualPRsNotifier, List<PersonalRecord>>(() {
  return ManualPRsNotifier();
});

final prTrackerProvider = Provider<PRState>((ref) {
  final trackerState = ref.watch(trackerProvider);
  final manualPRs = ref.watch(manualPRsProvider);
  final exercises = ref.watch(exercisesProvider).value ?? [];

  return _calculatePRs(trackerState.history, manualPRs, exercises);
});

PRState _calculatePRs(
  List<CompletedWorkout> history,
  List<PersonalRecord> manualPRs,
  List<Exercise> exercises,
) {
  final Map<String, PersonalRecord> heaviestWeight = {};
  final Map<String, PersonalRecord> mostReps = {};
  final Map<String, PersonalRecord> highestVolume = {};
  final List<PersonalRecord> allPRs = [];

  // 1. Calculate PRs from history
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

      // Time/distance logs store "mm:ss" / km in these fields - never PRs.
      if (liveEx.logMode == LogMode.timeAndReps ||
          liveEx.logMode == LogMode.timeAndDistance) {
        continue;
      }

      for (final set in liveEx.sets) {
        if (!set.isCompleted || !set.isWorking) continue;

        // Bodyweight / reps-only: only a "most reps" record makes sense.
        if (liveEx.logMode == LogMode.repsOnly) {
          final r = int.tryParse(set.reps.trim()) ?? 0;
          if (r > 0 &&
              (!mostReps.containsKey(exercise.id) ||
                  r > mostReps[exercise.id]!.reps)) {
            final pr = PersonalRecord(
              exerciseId: exercise.id,
              exerciseName: exercise.name,
              weight: 0,
              reps: r,
              date: workout.date,
              category: 'reps',
            );
            mostReps[exercise.id] = pr;
            allPRs.add(pr);
          }
          continue;
        }
        
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

  // 2. Merge manual PR overrides
  for (final pr in manualPRs) {
    final exerciseId = pr.exerciseId;
    if (pr.category == 'weight') {
      if (!heaviestWeight.containsKey(exerciseId) || pr.weight > heaviestWeight[exerciseId]!.weight) {
        heaviestWeight[exerciseId] = pr;
        allPRs.add(pr);
      }
    } else if (pr.category == 'reps') {
      if (!mostReps.containsKey(exerciseId) || pr.reps > mostReps[exerciseId]!.reps) {
        mostReps[exerciseId] = pr;
        allPRs.add(pr);
      }
    } else if (pr.category == 'volume') {
      if (!highestVolume.containsKey(exerciseId) || pr.volume > highestVolume[exerciseId]!.volume) {
        highestVolume[exerciseId] = pr;
        allPRs.add(pr);
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