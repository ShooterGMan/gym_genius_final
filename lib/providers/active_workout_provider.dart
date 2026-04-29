import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/notification_service.dart';
import '../providers/settings_provider.dart';
import '../providers/tracker_provider.dart';

enum LogMode {
  weightAndReps,
  repsOnly,
  timeAndReps,
  timeAndDistance,
}

class LiveSet {
  final String id;
  String weight;
  String reps;
  bool isCompleted;

  LiveSet({
    required this.id,
    this.weight = '',
    this.reps = '',
    this.isCompleted = false,
  });

  LiveSet copy() =>
      LiveSet(id: id, weight: weight, reps: reps, isCompleted: isCompleted);
}

class WorkoutExerciseLive {
  final String id;
  final String exerciseId;
  final List<LiveSet> sets;
  final LogMode logMode;

  WorkoutExerciseLive({
    required this.id,
    required this.exerciseId,
    required this.sets,
    this.logMode = LogMode.weightAndReps,
  });

  WorkoutExerciseLive copyWith({List<LiveSet>? sets, LogMode? logMode}) {
    return WorkoutExerciseLive(
      id: id,
      exerciseId: exerciseId,
      sets: sets ?? this.sets,
      logMode: logMode ?? this.logMode,
    );
  }

  WorkoutExerciseLive copy() => WorkoutExerciseLive(
        id: id,
        exerciseId: exerciseId,
        sets: sets.map((s) => s.copy()).toList(),
        logMode: logMode,
      );
}

class ActiveWorkoutState {
  final bool isActive;
  final int elapsedSeconds;
  final bool isResting;
  final int restSeconds;
  final int restSecondsTotal;
  final List<WorkoutExerciseLive> routine;
  final DateTime? startTime;

  ActiveWorkoutState({
    this.isActive = false,
    this.elapsedSeconds = 0,
    this.isResting = false,
    this.restSeconds = 0,
    this.restSecondsTotal = 90,
    this.routine = const [],
    this.startTime,
  });

  ActiveWorkoutState copyWith({
    bool? isActive,
    int? elapsedSeconds,
    bool? isResting,
    int? restSeconds,
    int? restSecondsTotal,
    List<WorkoutExerciseLive>? routine,
    DateTime? startTime,
  }) {
    return ActiveWorkoutState(
      isActive: isActive ?? this.isActive,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isResting: isResting ?? this.isResting,
      restSeconds: restSeconds ?? this.restSeconds,
      restSecondsTotal: restSecondsTotal ?? this.restSecondsTotal,
      routine: routine ?? this.routine,
      startTime: startTime ?? this.startTime,
    );
  }
}

final activeWorkoutProvider =
    NotifierProvider<ActiveWorkoutNotifier, ActiveWorkoutState>(() {
  return ActiveWorkoutNotifier();
});

class ActiveWorkoutNotifier extends Notifier<ActiveWorkoutState> {
  Timer? _workoutTimer;
  Timer? _restTimer;
  final _uuid = const Uuid();
  final _notificationService = NotificationService();
  static const String _stateKey = 'active_workout_state_v1';

  @override
  ActiveWorkoutState build() => ActiveWorkoutState();

  Future<void> restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final startTimeStr = prefs.getString('active_workout_start');

    if (startTimeStr != null) {
      final startTime = DateTime.parse(startTimeStr);
      final actualElapsed = DateTime.now().difference(startTime).inSeconds;
      final wasResting = prefs.getBool('active_workout_resting') ?? false;
      final restTime = prefs.getInt('active_workout_rest') ?? 0;
      final restTotal = prefs.getInt('active_workout_rest_total') ?? 90;

      state = ActiveWorkoutState(
        isActive: true,
        elapsedSeconds: actualElapsed,
        isResting: wasResting,
        restSeconds: restTime,
        restSecondsTotal: restTotal,
        startTime: startTime,
      );

      _startStopwatch();
      WakelockPlus.enable();

      if (wasResting && restTime > 0) {
        _startRestTimer(restTime);
      }
    }
  }

  Future<void> persistState() async {
    if (!state.isActive) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, 'active');
    await prefs.setInt('active_workout_elapsed', state.elapsedSeconds);
    await prefs.setBool('active_workout_resting', state.isResting);
    await prefs.setInt('active_workout_rest', state.restSeconds);
    await prefs.setInt('active_workout_rest_total', state.restSecondsTotal);
    if (state.startTime != null) {
      await prefs.setString(
          'active_workout_start', state.startTime!.toIso8601String());
    }
  }

  /// Get the last used weight/reps for an exercise from workout history
  Map<String, String>? _getPreviousExerciseData(String exerciseId) {
    final trackerState = ref.read(trackerProvider);
    if (trackerState.history.isEmpty) return null;

    // Find the most recent workout that contains this exercise
    for (final workout in trackerState.history) {
      for (final liveEx in workout.routine) {
        if (liveEx.exerciseId == exerciseId && liveEx.sets.isNotEmpty) {
          // Find the last completed set
          for (int i = liveEx.sets.length - 1; i >= 0; i--) {
            final set = liveEx.sets[i];
            if (set.isCompleted && set.weight.isNotEmpty && set.reps.isNotEmpty) {
              return {
                'weight': set.weight,
                'reps': set.reps,
              };
            }
          }
          // If no completed sets, use the last set's values
          final lastSet = liveEx.sets.last;
          if (lastSet.weight.isNotEmpty || lastSet.reps.isNotEmpty) {
            return {
              'weight': lastSet.weight,
              'reps': lastSet.reps,
            };
          }
        }
      }
    }
    return null;
  }

  void startEmptyWorkout() {
    _notificationService.init();

    state = ActiveWorkoutState(
      isActive: true,
      startTime: DateTime.now(),
    );
    _startStopwatch();
    WakelockPlus.enable();
  }

  void _startStopwatch() {
    _workoutTimer?.cancel();
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final newElapsed = state.elapsedSeconds + 1;
      state = state.copyWith(elapsedSeconds: newElapsed);

      if (newElapsed % 30 == 0) {
        _notificationService.showWorkoutNotification(
          formatTime(newElapsed),
          state.routine.length,
        );
      }
    });
  }

  String formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void addExercise(String exerciseId,
      {int setsCount = 1, String repsHint = ''}) {
    final liveExId = _uuid.v4();
    
    // Check for previous workout data
    final previousData = _getPreviousExerciseData(exerciseId);
    final weight = previousData?['weight'] ?? '';
    final reps = repsHint.isNotEmpty ? repsHint : (previousData?['reps'] ?? '');

    state = state.copyWith(
      routine: [
        ...state.routine,
        WorkoutExerciseLive(
          id: liveExId,
          exerciseId: exerciseId,
          sets: List.generate(
            setsCount,
            (i) => LiveSet(
              id: _uuid.v4(),
              weight: weight,
              reps: reps,
            ),
          ),
        )
      ],
    );
  }

  void setLogMode(String exerciseLiveId, LogMode mode) {
    state = state.copyWith(
      routine: [
        for (final ex in state.routine)
          if (ex.id == exerciseLiveId) ex.copyWith(logMode: mode) else ex
      ],
    );
  }

  void addSet(String exerciseLiveId) {
    // Get previous set data for the new set
    final exercise = state.routine.firstWhere((ex) => ex.id == exerciseLiveId);
    String weight = '';
    String reps = '';
    
    // Find last completed set for pre-fill
    for (int i = exercise.sets.length - 1; i >= 0; i--) {
      final set = exercise.sets[i];
      if (set.isCompleted && set.weight.isNotEmpty) {
        weight = set.weight;
        reps = set.reps;
        break;
      }
    }

    state = state.copyWith(
      routine: [
        for (final ex in state.routine)
          if (ex.id == exerciseLiveId)
            ex.copyWith(sets: [
              ...ex.sets,
              LiveSet(id: _uuid.v4(), weight: weight, reps: reps)
            ])
          else
            ex
      ],
    );
  }

  void updateSet(
      String exerciseLiveId, String setId, String field, String value) {
    final updatedRoutine = state.routine.map((ex) {
      if (ex.id == exerciseLiveId) {
        final updatedSets = ex.sets.map((set) {
          if (set.id == setId) {
            if (field == 'weight') set.weight = value;
            if (field == 'reps') set.reps = value;
          }
          return set;
        }).toList();
        return ex.copyWith(sets: updatedSets);
      }
      return ex;
    }).toList();
    state = state.copyWith(routine: updatedRoutine);
  }

  void toggleSetComplete(String exerciseLiveId, String setId) {
    bool newlyCompleted = false;
    final updatedRoutine = state.routine.map((ex) {
      if (ex.id == exerciseLiveId) {
        final updatedSets = ex.sets.map((set) {
          if (set.id == setId) {
            newlyCompleted = !set.isCompleted;
            return LiveSet(
                id: set.id,
                weight: set.weight,
                reps: set.reps,
                isCompleted: newlyCompleted);
          }
          return set;
        }).toList();
        return ex.copyWith(sets: updatedSets);
      }
      return ex;
    }).toList();

    state = state.copyWith(routine: updatedRoutine);
    if (newlyCompleted) {
      final settingsState = ref.read(settingsProvider);
      final restTime = settingsState.defaultRestTime;
      _startRestTimer(restTime);
    }
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    state = state.copyWith(
      isResting: true,
      restSeconds: seconds,
      restSecondsTotal: seconds,
    );

    _notificationService.showRestTimerNotification(seconds, seconds);

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.restSeconds > 0) {
        final newRestSeconds = state.restSeconds - 1;
        state = state.copyWith(restSeconds: newRestSeconds);
        _notificationService.showRestTimerNotification(
            newRestSeconds, state.restSecondsTotal);
      } else {
        timer.cancel();
        state = state.copyWith(isResting: false);
        _notificationService.cancelRestTimerNotification();
      }
    });
  }

  void adjustRestTimer(int adjustmentSeconds) {
    if (!state.isResting) return;

    final newTotal = (state.restSecondsTotal + adjustmentSeconds).clamp(5, 300);
    final newCurrent = (state.restSeconds + adjustmentSeconds).clamp(0, 300);

    state = state.copyWith(
      restSeconds: newCurrent,
      restSecondsTotal: newTotal,
    );

    _notificationService.showRestTimerNotification(newCurrent, newTotal);

    if (newCurrent <= 0) {
      _restTimer?.cancel();
      state = state.copyWith(isResting: false);
      _notificationService.cancelRestTimerNotification();
    }
  }

  void skipRest() {
    _restTimer?.cancel();
    state = state.copyWith(isResting: false, restSeconds: 0);
    _notificationService.cancelRestTimerNotification();
  }

  void endWorkout() {
    _workoutTimer?.cancel();
    _restTimer?.cancel();

    WakelockPlus.disable();
    _notificationService.cancelWorkoutNotification();
    _notificationService.cancelRestTimerNotification();

    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_stateKey);
      prefs.remove('active_workout_elapsed');
      prefs.remove('active_workout_resting');
      prefs.remove('active_workout_rest');
      prefs.remove('active_workout_rest_total');
      prefs.remove('active_workout_start');
    });

    state = ActiveWorkoutState();
  }
}