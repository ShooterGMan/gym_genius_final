import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/program.dart';
import '../services/notification_service.dart';
import '../providers/settings_provider.dart';
import '../providers/tracker_provider.dart';

enum LogMode {
  weightAndReps,
  repsOnly,
  timeAndReps,
  timeAndDistance,
}

enum SetType { normal, warmup, drop, failure }

extension SetTypeLabel on SetType {
  String get label {
    switch (this) {
      case SetType.normal:
        return 'Normal';
      case SetType.warmup:
        return 'Warm-up';
      case SetType.drop:
        return 'Drop set';
      case SetType.failure:
        return 'To failure';
    }
  }

  /// Short marker shown instead of the set number ('' for normal sets).
  String get marker {
    switch (this) {
      case SetType.normal:
        return '';
      case SetType.warmup:
        return 'W';
      case SetType.drop:
        return 'D';
      case SetType.failure:
        return 'F';
    }
  }
}

class LiveSet {
  final String id;
  String weight;
  String reps;
  bool isCompleted;
  final SetType type;

  /// Rate of perceived exertion (6-10, half steps). Optional.
  final double? rpe;

  LiveSet({
    required this.id,
    this.weight = '',
    this.reps = '',
    this.isCompleted = false,
    this.type = SetType.normal,
    this.rpe,
  });

  /// Warm-up sets never count toward volume or personal records.
  bool get isWorking => type != SetType.warmup;

  LiveSet copy() => copyWith();

  LiveSet copyWith({
    String? weight,
    String? reps,
    bool? isCompleted,
    SetType? type,
    double? rpe,
    bool clearRpe = false,
  }) =>
      LiveSet(
        id: id,
        weight: weight ?? this.weight,
        reps: reps ?? this.reps,
        isCompleted: isCompleted ?? this.isCompleted,
        type: type ?? this.type,
        rpe: clearRpe ? null : (rpe ?? this.rpe),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'w': weight,
        'r': reps,
        'c': isCompleted,
        if (type != SetType.normal) 't': type.index,
        if (rpe != null) 'rpe': rpe,
      };

  static SetType typeFromIndex(dynamic v) {
    final i = v is int ? v : 0;
    return SetType.values[i.clamp(0, SetType.values.length - 1)];
  }

  factory LiveSet.fromMap(Map<String, dynamic> map) => LiveSet(
        id: map['id'] ?? const Uuid().v4(),
        weight: map['w']?.toString() ?? '',
        reps: map['r']?.toString() ?? '',
        isCompleted: map['c'] ?? false,
        type: typeFromIndex(map['t']),
        rpe: (map['rpe'] as num?)?.toDouble(),
      );
}

class WorkoutExerciseLive {
  final String id;
  final String exerciseId;
  final List<LiveSet> sets;
  final LogMode logMode;

  /// Target from the program (e.g. "8-12", "Max", "45 sec"). Shown as a hint.
  final String? targetReps;

  /// Per-exercise rest from the program. Falls back to the user's default.
  final int? restSeconds;

  /// Exercises sharing the same id are performed back-to-back (superset).
  final String? supersetId;

  WorkoutExerciseLive({
    required this.id,
    required this.exerciseId,
    required this.sets,
    this.logMode = LogMode.weightAndReps,
    this.targetReps,
    this.restSeconds,
    this.supersetId,
  });

  WorkoutExerciseLive copyWith({
    List<LiveSet>? sets,
    LogMode? logMode,
    String? supersetId,
    bool clearSuperset = false,
  }) {
    return WorkoutExerciseLive(
      id: id,
      exerciseId: exerciseId,
      sets: sets ?? this.sets,
      logMode: logMode ?? this.logMode,
      targetReps: targetReps,
      restSeconds: restSeconds,
      supersetId: clearSuperset ? null : (supersetId ?? this.supersetId),
    );
  }

  WorkoutExerciseLive copy() =>
      copyWith(sets: sets.map((s) => s.copy()).toList());

  /// Whether weight x reps volume / PRs make sense for this exercise.
  bool get tracksWeight => logMode == LogMode.weightAndReps;

  Map<String, dynamic> toMap() => {
        'id': id,
        'exId': exerciseId,
        'mode': logMode.index,
        'target': targetReps,
        'rest': restSeconds,
        'ss': supersetId,
        'sets': sets.map((s) => s.toMap()).toList(),
      };

  factory WorkoutExerciseLive.fromMap(Map<String, dynamic> map) {
    final modeIdx = map['mode'] is int ? map['mode'] as int : 0;
    return WorkoutExerciseLive(
      id: map['id'] ?? const Uuid().v4(),
      exerciseId: map['exId'] ?? '',
      logMode: LogMode.values[modeIdx.clamp(0, LogMode.values.length - 1)],
      targetReps: map['target'],
      restSeconds: map['rest'],
      supersetId: map['ss'],
      sets: (map['sets'] as List? ?? [])
          .map((s) => LiveSet.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }
}

class ActiveWorkoutState {
  final bool isActive;
  final int elapsedSeconds;
  final bool isResting;
  final int restSeconds;
  final int restSecondsTotal;
  final List<WorkoutExerciseLive> routine;
  final DateTime? startTime;
  final String? name;

  ActiveWorkoutState({
    this.isActive = false,
    this.elapsedSeconds = 0,
    this.isResting = false,
    this.restSeconds = 0,
    this.restSecondsTotal = 90,
    this.routine = const [],
    this.startTime,
    this.name,
  });

  ActiveWorkoutState copyWith({
    bool? isActive,
    int? elapsedSeconds,
    bool? isResting,
    int? restSeconds,
    int? restSecondsTotal,
    List<WorkoutExerciseLive>? routine,
    DateTime? startTime,
    String? name,
  }) {
    return ActiveWorkoutState(
      isActive: isActive ?? this.isActive,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isResting: isResting ?? this.isResting,
      restSeconds: restSeconds ?? this.restSeconds,
      restSecondsTotal: restSecondsTotal ?? this.restSecondsTotal,
      routine: routine ?? this.routine,
      startTime: startTime ?? this.startTime,
      name: name ?? this.name,
    );
  }

  int get completedSetCount => routine.fold(
      0, (sum, ex) => sum + ex.sets.where((s) => s.isCompleted).length);
}

final activeWorkoutProvider =
    NotifierProvider<ActiveWorkoutNotifier, ActiveWorkoutState>(() {
  return ActiveWorkoutNotifier();
});

class ActiveWorkoutNotifier extends Notifier<ActiveWorkoutState> {
  Timer? _workoutTimer;
  Timer? _restTimer;
  Timer? _persistDebounce;

  /// Wall-clock moment the current rest period ends. Timers are derived from
  /// wall-clock time so they stay correct when the app is backgrounded or
  /// the OS throttles Dart timers.
  DateTime? _restEnd;

  final _uuid = const Uuid();
  final _notificationService = NotificationService();
  static const String _sessionKey = 'active_workout_session_v2';

  // Legacy keys (v1 only stored timers, never the exercises).
  static const _legacyKeys = [
    'active_workout_state_v1',
    'active_workout_elapsed',
    'active_workout_resting',
    'active_workout_rest',
    'active_workout_rest_total',
    'active_workout_start',
  ];

  @override
  ActiveWorkoutState build() {
    ref.onDispose(() {
      _workoutTimer?.cancel();
      _restTimer?.cancel();
      _persistDebounce?.cancel();
    });
    return ActiveWorkoutState();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) {
      // Clean up the old timer-only format; it can't be restored meaningfully.
      for (final k in _legacyKeys) {
        prefs.remove(k);
      }
      return;
    }

    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final startTime = DateTime.parse(map['start']);
      final routine = (map['routine'] as List? ?? [])
          .map((e) => WorkoutExerciseLive.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      final restEndStr = map['restEnd'] as String?;
      final restEnd = restEndStr != null ? DateTime.parse(restEndStr) : null;
      final restTotal = map['restTotal'] as int? ?? 90;

      state = ActiveWorkoutState(
        isActive: true,
        elapsedSeconds: DateTime.now().difference(startTime).inSeconds,
        startTime: startTime,
        routine: routine,
        restSecondsTotal: restTotal,
        name: map['name'],
      );

      _startStopwatch();
      WakelockPlus.enable();

      if (restEnd != null && restEnd.isAfter(DateTime.now())) {
        _resumeRestTimer(restEnd, restTotal);
      }
    } catch (e) {
      debugPrint('Could not restore active workout: $e');
      await prefs.remove(_sessionKey);
    }
  }

  Future<void> persistState() async {
    _persistDebounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    if (!state.isActive || state.startTime == null) {
      await prefs.remove(_sessionKey);
      return;
    }
    await prefs.setString(
      _sessionKey,
      json.encode({
        'start': state.startTime!.toIso8601String(),
        'name': state.name,
        'restEnd': _restEnd?.toIso8601String(),
        'restTotal': state.restSecondsTotal,
        'routine': state.routine.map((e) => e.toMap()).toList(),
      }),
    );
  }

  /// Persist shortly after any edit so a crash / OS kill never loses sets.
  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce =
        Timer(const Duration(milliseconds: 600), () => persistState());
  }

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  /// Get the last completed weight/reps for an exercise from workout history.
  List<Map<String, String>>? _getPreviousExerciseSets(String exerciseId) {
    final trackerState = ref.read(trackerProvider);
    for (final workout in trackerState.history) {
      for (final liveEx in workout.routine) {
        if (liveEx.exerciseId != exerciseId) continue;
        final done = liveEx.sets.where((s) => s.isCompleted).toList();
        if (done.isNotEmpty) {
          return done.map((s) => {'weight': s.weight, 'reps': s.reps}).toList();
        }
      }
    }
    return null;
  }

  void startEmptyWorkout({String? name}) {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    _restEnd = null;
    _notificationService.init();

    state = ActiveWorkoutState(
      isActive: true,
      startTime: DateTime.now(),
      name: name,
    );
    _startStopwatch();
    WakelockPlus.enable();
    _schedulePersist();
  }

  /// Start a workout pre-filled with a program routine.
  void startRoutine(WorkoutRoutine routine) {
    startEmptyWorkout(name: routine.name);
    for (final planned in routine.exercises) {
      addExercise(
        planned.exerciseId,
        setsCount: planned.sets < 1 ? 1 : planned.sets,
        repsHint: planned.reps,
        restSeconds: planned.restSeconds,
      );
    }
  }

  void _startStopwatch() {
    _workoutTimer?.cancel();
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final start = state.startTime;
      if (start == null) return;
      final newElapsed = DateTime.now().difference(start).inSeconds;
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
    if (seconds < 0) seconds = 0;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  void endWorkout() {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    _persistDebounce?.cancel();
    _restEnd = null;

    WakelockPlus.disable();
    _notificationService.cancelWorkoutNotification();
    _notificationService.cancelRestTimerNotification();
    _notificationService.cancelScheduledRestFinished();

    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_sessionKey);
      for (final k in _legacyKeys) {
        prefs.remove(k);
      }
    });

    state = ActiveWorkoutState();
  }

  /// Ends the session without saving anything.
  void discardWorkout() => endWorkout();

  // ---------------------------------------------------------------------------
  // Exercises & sets
  // ---------------------------------------------------------------------------

  void addExercise(
    String exerciseId, {
    int setsCount = 1,
    String repsHint = '',
    int? restSeconds,
  }) {
    final previousSets = _getPreviousExerciseSets(exerciseId);
    // Only pre-fill reps with the program target if it is a plain number;
    // targets like "8-12", "Max" or "45 sec" are shown as hints instead.
    final numericHint = int.tryParse(repsHint.trim()) != null ? repsHint.trim() : '';

    state = state.copyWith(
      routine: [
        ...state.routine,
        WorkoutExerciseLive(
          id: _uuid.v4(),
          exerciseId: exerciseId,
          targetReps: repsHint.trim().isEmpty ? null : repsHint.trim(),
          restSeconds: restSeconds,
          sets: List.generate(setsCount, (i) {
            String weight = '';
            String reps = numericHint;
            if (previousSets != null && previousSets.isNotEmpty) {
              final prevIdx =
                  i < previousSets.length ? i : previousSets.length - 1;
              weight = previousSets[prevIdx]['weight'] ?? '';
              if (reps.isEmpty) reps = previousSets[prevIdx]['reps'] ?? '';
            }
            return LiveSet(id: _uuid.v4(), weight: weight, reps: reps);
          }),
        )
      ],
    );
    _schedulePersist();
  }

  void removeExercise(String exerciseLiveId) {
    state = state.copyWith(
      routine: _cleanupSupersets(
          state.routine.where((e) => e.id != exerciseLiveId).toList()),
    );
    _schedulePersist();
  }

  /// Re-inserts an exercise (used for "Undo" after removal).
  void insertExercise(int index, WorkoutExerciseLive exercise) {
    final list = [...state.routine];
    list.insert(index.clamp(0, list.length), exercise);
    state = state.copyWith(routine: list);
    _schedulePersist();
  }

  void moveExercise(int oldIndex, int newIndex) {
    final list = [...state.routine];
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), item);
    state = state.copyWith(routine: list);
    _schedulePersist();
  }

  void setLogMode(String exerciseLiveId, LogMode mode) {
    state = state.copyWith(
      routine: [
        for (final ex in state.routine)
          if (ex.id == exerciseLiveId) ex.copyWith(logMode: mode) else ex
      ],
    );
    _schedulePersist();
  }

  void addSet(String exerciseLiveId) {
    final idx = state.routine.indexWhere((ex) => ex.id == exerciseLiveId);
    if (idx == -1) return;
    final exercise = state.routine[idx];

    // Copy the last set (completed or not) so the user only has to tweak it.
    String weight = '';
    String reps = '';
    if (exercise.sets.isNotEmpty) {
      weight = exercise.sets.last.weight;
      reps = exercise.sets.last.reps;
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
    _schedulePersist();
  }

  void removeSet(String exerciseLiveId, String setId) {
    state = state.copyWith(
      routine: [
        for (final ex in state.routine)
          if (ex.id == exerciseLiveId)
            ex.copyWith(sets: ex.sets.where((s) => s.id != setId).toList())
          else
            ex
      ],
    );
    _schedulePersist();
  }

  void _updateOneSet(
      String exerciseLiveId, String setId, LiveSet Function(LiveSet) f) {
    state = state.copyWith(
      routine: [
        for (final ex in state.routine)
          if (ex.id == exerciseLiveId)
            ex.copyWith(sets: [
              for (final set in ex.sets)
                if (set.id == setId) f(set) else set
            ])
          else
            ex
      ],
    );
    _schedulePersist();
  }

  void updateSet(
      String exerciseLiveId, String setId, String field, String value) {
    _updateOneSet(
        exerciseLiveId,
        setId,
        (s) => s.copyWith(
              weight: field == 'weight' ? value : null,
              reps: field == 'reps' ? value : null,
            ));
  }

  /// Fill a set with given values in one go (e.g. tapping "previous").
  void fillSet(String exerciseLiveId, String setId,
      {required String weight, required String reps}) {
    _updateOneSet(
        exerciseLiveId, setId, (s) => s.copyWith(weight: weight, reps: reps));
  }

  void setSetType(String exerciseLiveId, String setId, SetType type) {
    _updateOneSet(exerciseLiveId, setId, (s) => s.copyWith(type: type));
  }

  void setRpe(String exerciseLiveId, String setId, double? rpe) {
    _updateOneSet(exerciseLiveId, setId,
        (s) => rpe == null ? s.copyWith(clearRpe: true) : s.copyWith(rpe: rpe));
  }

  /// Links this exercise with the next one in the list into a superset.
  void supersetWithNext(String exerciseLiveId) {
    final list = [...state.routine];
    final i = list.indexWhere((e) => e.id == exerciseLiveId);
    if (i == -1 || i + 1 >= list.length) return;
    final groupId = list[i].supersetId ?? list[i + 1].supersetId ?? _uuid.v4();
    final nextOldGroup = list[i + 1].supersetId;
    for (var j = 0; j < list.length; j++) {
      final e = list[j];
      // Merge the next exercise's existing group into ours.
      if (j == i || j == i + 1 || (nextOldGroup != null && e.supersetId == nextOldGroup)) {
        list[j] = e.copyWith(supersetId: groupId);
      }
    }
    state = state.copyWith(routine: list);
    _schedulePersist();
  }

  void removeFromSuperset(String exerciseLiveId) {
    final list = [
      for (final e in state.routine)
        if (e.id == exerciseLiveId) e.copyWith(clearSuperset: true) else e
    ];
    state = state.copyWith(routine: _cleanupSupersets(list));
    _schedulePersist();
  }

  /// A "superset" of one exercise is meaningless - dissolve it.
  List<WorkoutExerciseLive> _cleanupSupersets(List<WorkoutExerciseLive> list) {
    final counts = <String, int>{};
    for (final e in list) {
      if (e.supersetId != null) {
        counts[e.supersetId!] = (counts[e.supersetId!] ?? 0) + 1;
      }
    }
    return [
      for (final e in list)
        if (e.supersetId != null && (counts[e.supersetId!] ?? 0) < 2)
          e.copyWith(clearSuperset: true)
        else
          e
    ];
  }

  void toggleSetComplete(String exerciseLiveId, String setId) {
    bool newlyCompleted = false;
    int? exerciseRest;
    final updatedRoutine = state.routine.map((ex) {
      if (ex.id != exerciseLiveId) return ex;
      exerciseRest = ex.restSeconds;
      return ex.copyWith(
        sets: ex.sets.map((set) {
          if (set.id != setId) return set;
          newlyCompleted = !set.isCompleted;
          return set.copyWith(isCompleted: newlyCompleted);
        }).toList(),
      );
    }).toList();

    state = state.copyWith(routine: updatedRoutine);
    if (newlyCompleted) {
      HapticFeedback.lightImpact();
      // In a superset you rest only after the last exercise of the round.
      if (!_isMidSuperset(exerciseLiveId)) {
        final restTime =
            exerciseRest ?? ref.read(settingsProvider).defaultRestTime;
        if (restTime > 0) _startRestTimer(restTime);
      }
    }
    _schedulePersist();
  }

  bool _isMidSuperset(String exerciseLiveId) {
    final ex = state.routine.where((e) => e.id == exerciseLiveId);
    if (ex.isEmpty || ex.first.supersetId == null) return false;
    final group = state.routine
        .where((e) => e.supersetId == ex.first.supersetId)
        .toList();
    return group.last.id != exerciseLiveId;
  }

  // ---------------------------------------------------------------------------
  // Rest timer
  // ---------------------------------------------------------------------------

  void _startRestTimer(int seconds) {
    _resumeRestTimer(DateTime.now().add(Duration(seconds: seconds)), seconds);
    _schedulePersist();
  }

  void _resumeRestTimer(DateTime end, int total) {
    _restTimer?.cancel();
    _restEnd = end;
    final remaining = _remainingRest();
    state = state.copyWith(
      isResting: true,
      restSeconds: remaining,
      restSecondsTotal: total,
    );

    _notificationService.showRestTimerNotification(remaining, total);
    _notificationService.scheduleRestFinished(end);

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = _remainingRest();
      if (left > 0) {
        state = state.copyWith(restSeconds: left);
      } else {
        timer.cancel();
        _finishRest();
      }
    });
  }

  int _remainingRest() {
    final end = _restEnd;
    if (end == null) return 0;
    final ms = end.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _finishRest() {
    _restTimer?.cancel();
    _restEnd = null;
    state = state.copyWith(isResting: false, restSeconds: 0);
    _notificationService.cancelRestTimerNotification();
    // The "rest finished" alert was scheduled at timer start, so it fires even
    // if the app was suspended. Here we only add in-app haptics.
    HapticFeedback.vibrate();
    Future.delayed(const Duration(milliseconds: 300), HapticFeedback.vibrate);
    _schedulePersist();
  }

  void adjustRestTimer(int adjustmentSeconds) {
    if (!state.isResting || _restEnd == null) return;

    final newEnd = _restEnd!.add(Duration(seconds: adjustmentSeconds));
    final newTotal =
        (state.restSecondsTotal + adjustmentSeconds).clamp(5, 600);

    if (!newEnd.isAfter(DateTime.now())) {
      _notificationService.cancelScheduledRestFinished();
      _finishRest();
      return;
    }
    _resumeRestTimer(newEnd, newTotal);
    _schedulePersist();
  }

  void skipRest() {
    _restTimer?.cancel();
    _restEnd = null;
    state = state.copyWith(isResting: false, restSeconds: 0);
    _notificationService.cancelRestTimerNotification();
    _notificationService.cancelScheduledRestFinished();
    _schedulePersist();
  }
}
