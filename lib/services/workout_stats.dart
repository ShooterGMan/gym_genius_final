import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/active_workout_provider.dart';
import '../providers/tracker_provider.dart';

/// Estimated one-rep max (Epley). Returns 0 when it can't be estimated.
/// Above ~12 reps the estimate gets unreliable, so we cap the reps used.
double estimate1RM(double weight, int reps) {
  if (weight <= 0 || reps <= 0) return 0;
  if (reps == 1) return weight;
  final r = reps > 12 ? 12 : reps;
  return weight * (1 + r / 30.0);
}

double parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;
int parseInt(String s) => int.tryParse(s.trim()) ?? parseNum(s).round();

/// Trims trailing ".0" so 60.0 shows as "60".
String fmtNum(double v, {int decimals = 1}) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(decimals);
}

/// "60×8", "12 reps", "1:30 · 10" etc. depending on the log mode.
String formatSet(LiveSet s, LogMode mode) {
  switch (mode) {
    case LogMode.weightAndReps:
      if (s.weight.isEmpty && s.reps.isEmpty) return '—';
      if (s.weight.isEmpty) return '${s.reps} reps';
      return '${s.weight}×${s.reps.isEmpty ? '?' : s.reps}';
    case LogMode.repsOnly:
      // Older logs stored reps in the weight field.
      final r = s.reps.isNotEmpty ? s.reps : s.weight;
      return r.isEmpty ? '—' : '$r reps';
    case LogMode.timeAndReps:
      return [s.weight, s.reps].where((x) => x.isNotEmpty).join(' · ');
    case LogMode.timeAndDistance:
      return [s.weight, if (s.reps.isNotEmpty) '${s.reps} km']
          .where((x) => x.isNotEmpty)
          .join(' · ');
  }
}

/// One exercise's performance within one workout.
class ExerciseSession {
  final String workoutId;
  final DateTime date;
  final LogMode mode;
  final List<LiveSet> sets; // completed sets, incl. warm-ups, in order

  ExerciseSession({
    required this.workoutId,
    required this.date,
    required this.mode,
    required this.sets,
  });

  Iterable<LiveSet> get working => sets.where((s) => s.isWorking);

  double get bestE1RM => mode != LogMode.weightAndReps
      ? 0
      : working.fold(0.0, (best, s) {
          final e = estimate1RM(parseNum(s.weight), parseInt(s.reps));
          return e > best ? e : best;
        });

  double get topWeight => mode != LogMode.weightAndReps
      ? 0
      : working.fold(0.0, (best, s) {
          final w = parseNum(s.weight);
          return w > best ? w : best;
        });

  int get maxReps => working.fold(0, (best, s) {
        final r = parseInt(mode == LogMode.repsOnly && s.reps.isEmpty
            ? s.weight
            : s.reps);
        return r > best ? r : best;
      });

  double get volume => mode != LogMode.weightAndReps
      ? 0
      : working.fold(
          0.0, (sum, s) => sum + parseNum(s.weight) * parseInt(s.reps));

  /// The single best working set (by estimated 1RM, or reps for bodyweight).
  LiveSet? get bestSet {
    LiveSet? best;
    double bestScore = -1;
    for (final s in working) {
      final score = mode == LogMode.weightAndReps
          ? estimate1RM(parseNum(s.weight), parseInt(s.reps))
          : parseInt(s.reps.isEmpty ? s.weight : s.reps).toDouble();
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return best;
  }
}

/// All sessions of an exercise, newest first.
List<ExerciseSession> exerciseSessions(
    List<CompletedWorkout> history, String exerciseId) {
  final out = <ExerciseSession>[];
  for (final w in history) {
    for (final ex in w.routine) {
      if (ex.exerciseId != exerciseId) continue;
      final done = ex.sets.where((s) => s.isCompleted).toList();
      if (done.isEmpty) continue;
      out.add(ExerciseSession(
          workoutId: w.id, date: w.date, mode: ex.logMode, sets: done));
    }
  }
  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
}

final exerciseSessionsProvider =
    Provider.family<List<ExerciseSession>, String>((ref, exerciseId) {
  final history = ref.watch(trackerProvider).history;
  return exerciseSessions(history, exerciseId);
});

/// A record set during a specific workout.
class WorkoutPR {
  final String exerciseId;
  final String kind; // 'e1rm' | 'weight' | 'reps'
  final double value;
  final String setText;
  WorkoutPR(this.exerciseId, this.kind, this.value, this.setText);
}

/// Records beaten in [workout] compared to everything logged before it.
List<WorkoutPR> prsInWorkout(
    CompletedWorkout workout, List<CompletedWorkout> history) {
  final prs = <WorkoutPR>[];
  final earlier = history.where((w) => w.date.isBefore(workout.date)).toList();
  for (final ex in workout.routine) {
    final done = ex.sets.where((s) => s.isCompleted).toList();
    if (done.isEmpty) continue;
    final now = ExerciseSession(
        workoutId: workout.id, date: workout.date, mode: ex.logMode, sets: done);
    final before = exerciseSessions(earlier, ex.exerciseId)
        .where((s) => s.mode == ex.logMode)
        .toList();
    if (before.isEmpty) continue; // first time isn't a "PR", it's a baseline
    final best = now.bestSet;
    if (best == null) continue;

    if (ex.logMode == LogMode.weightAndReps) {
      final prevE1 = before.fold(0.0, (m, s) => s.bestE1RM > m ? s.bestE1RM : m);
      final prevTop = before.fold(0.0, (m, s) => s.topWeight > m ? s.topWeight : m);
      if (now.topWeight > prevTop) {
        prs.add(WorkoutPR(ex.exerciseId, 'weight', now.topWeight,
            formatSet(best, ex.logMode)));
      } else if (now.bestE1RM > prevE1 + 0.01) {
        prs.add(WorkoutPR(ex.exerciseId, 'e1rm', now.bestE1RM,
            formatSet(best, ex.logMode)));
      }
    } else if (ex.logMode == LogMode.repsOnly) {
      final prevReps = before.fold(0, (m, s) => s.maxReps > m ? s.maxReps : m);
      if (now.maxReps > prevReps) {
        prs.add(WorkoutPR(ex.exerciseId, 'reps', now.maxReps.toDouble(),
            formatSet(best, ex.logMode)));
      }
    }
  }
  return prs;
}
