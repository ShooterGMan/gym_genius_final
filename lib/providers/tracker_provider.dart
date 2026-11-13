import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'active_workout_provider.dart';
import '../models/exercise.dart';

class ProgressPhoto {
  final String id;
  final DateTime date;
  final String imagePath;
  ProgressPhoto(
      {required this.id, required this.date, required this.imagePath});

  Map<String, dynamic> toMap() =>
      {'id': id, 'date': date.toIso8601String(), 'path': imagePath};
  factory ProgressPhoto.fromMap(Map<String, dynamic> map) => ProgressPhoto(
      id: map['id'], date: DateTime.parse(map['date']), imagePath: map['path']);
}

class CompletedWorkout {
  final String id;
  final DateTime date;
  final int durationSeconds;
  final double totalVolume;
  final List<WorkoutExerciseLive> routine;
  final String? name;

  CompletedWorkout(
      {required this.id,
      required this.date,
      required this.durationSeconds,
      required this.totalVolume,
      required this.routine,
      this.name});

  int get totalSets => routine.fold(
      0, (sum, ex) => sum + ex.sets.where((s) => s.isCompleted).length);

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'duration': durationSeconds,
        'volume': totalVolume,
        'name': name,
        'routine': routine
            .map((ex) => {
                  'exId': ex.exerciseId,
                  'mode': ex.logMode.index,
                  if (ex.supersetId != null) 'ss': ex.supersetId,
                  'sets': ex.sets
                      .map((s) => {
                            'w': s.weight,
                            'r': s.reps,
                            if (s.type != SetType.normal) 't': s.type.index,
                            if (s.rpe != null) 'rpe': s.rpe,
                          })
                      .toList(),
                })
            .toList(),
      };

  factory CompletedWorkout.fromMap(Map<String, dynamic> map) =>
      CompletedWorkout(
        id: map['id'] ?? const Uuid().v4(),
        date: DateTime.parse(map['date']),
        durationSeconds: (map['duration'] as num?)?.toInt() ?? 0,
        totalVolume: (map['volume'] as num?)?.toDouble() ?? 0,
        name: map['name'],
        routine: (map['routine'] as List? ?? []).map((ex) {
          final modeIdx = (ex['mode'] as int?) ?? 0;
          return WorkoutExerciseLive(
            id: const Uuid().v4(),
            exerciseId: ex['exId'] ?? '',
            logMode:
                LogMode.values[modeIdx.clamp(0, LogMode.values.length - 1)],
            supersetId: ex['ss'],
            sets: (ex['sets'] as List? ?? [])
                .map((s) => LiveSet(
                    id: const Uuid().v4(),
                    weight: s['w']?.toString() ?? '',
                    reps: s['r']?.toString() ?? '',
                    type: LiveSet.typeFromIndex(s['t']),
                    rpe: (s['rpe'] as num?)?.toDouble(),
                    // History only stores completed sets.
                    isCompleted: true))
                .toList(),
          );
        }).toList(),
      );
}

class BodyMetric {
  final DateTime date;
  final String weight, bodyFat;
  BodyMetric({required this.date, this.weight = '', this.bodyFat = ''});
  Map<String, dynamic> toMap() =>
      {'date': date.toIso8601String(), 'weight': weight, 'bodyFat': bodyFat};
  factory BodyMetric.fromMap(Map<String, dynamic> map) => BodyMetric(
      date: DateTime.parse(map['date']),
      weight: map['weight'] ?? '',
      bodyFat: map['bodyFat'] ?? '');
}

class TrackerState {
  final List<CompletedWorkout> history;
  final List<BodyMetric> metrics;
  final List<ProgressPhoto> photos;
  TrackerState(
      {this.history = const [],
      this.metrics = const [],
      this.photos = const []});

  TrackerState copyWith(
      {List<CompletedWorkout>? history,
      List<BodyMetric>? metrics,
      List<ProgressPhoto>? photos}) {
    return TrackerState(
        history: history ?? this.history,
        metrics: metrics ?? this.metrics,
        photos: photos ?? this.photos);
  }
}

final trackerProvider =
    NotifierProvider<TrackerNotifier, TrackerState>(() => TrackerNotifier());

class TrackerNotifier extends Notifier<TrackerState> {
  static const String _historyKey = 'gym_history_v1';
  static const String _metricsKey = 'gym_metrics_v2';
  static const String _photosKey = 'gym_photos_v1';

  @override
  TrackerState build() {
    _loadData();
    return TrackerState();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final hStr = prefs.getString(_historyKey);
    final mStr = prefs.getString(_metricsKey);
    final pStr = prefs.getString(_photosKey);

    // Parse each record independently so one corrupt entry can never wipe
    // out (or crash) the user's whole history.
    List<T> parse<T>(String? raw, T Function(Map<String, dynamic>) f) {
      if (raw == null) return [];
      try {
        final out = <T>[];
        for (final x in json.decode(raw) as List) {
          try {
            out.add(f(Map<String, dynamic>.from(x)));
          } catch (e) {
            debugPrint('Skipping corrupt record: $e');
          }
        }
        return out;
      } catch (e) {
        debugPrint('Could not decode stored data: $e');
        return [];
      }
    }

    final h = parse(hStr, CompletedWorkout.fromMap)
      ..sort((a, b) => b.date.compareTo(a.date));
    final m = parse(mStr, BodyMetric.fromMap);
    final p = parse(pStr, ProgressPhoto.fromMap);
    state = TrackerState(history: h, metrics: m, photos: p);
  }

  /// Saves only completed sets; exercises with no completed sets are dropped.
  /// Returns the saved workout, or null if nothing was completed.
  Future<CompletedWorkout?> saveWorkout(ActiveWorkoutState session) async {
    final routine = <WorkoutExerciseLive>[];
    double calcVolume = 0;
    for (final ex in session.routine) {
      final done =
          ex.sets.where((s) => s.isCompleted).map((s) => s.copy()).toList();
      if (done.isEmpty) continue;
      if (ex.tracksWeight) {
        for (final set in done.where((s) => s.isWorking)) {
          calcVolume += (double.tryParse(set.weight) ?? 0) *
              (double.tryParse(set.reps) ?? 0);
        }
      }
      routine.add(ex.copyWith(sets: done));
    }
    if (routine.isEmpty) return null;

    final newWorkout = CompletedWorkout(
        id: const Uuid().v4(),
        date: DateTime.now(),
        durationSeconds: session.startTime != null
            ? DateTime.now().difference(session.startTime!).inSeconds
            : session.elapsedSeconds,
        totalVolume: calcVolume,
        name: session.name,
        routine: routine);
    final updatedHistory = [newWorkout, ...state.history];
    state = state.copyWith(history: updatedHistory);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey,
        json.encode(updatedHistory.map((x) => x.toMap()).toList()));
    return newWorkout;
  }

  Future<void> deleteWorkout(String id) async {
    final updatedHistory = state.history.where((w) => w.id != id).toList();
    state = state.copyWith(history: updatedHistory);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey,
        json.encode(updatedHistory.map((x) => x.toMap()).toList()));
  }

  Future<void> addBodyMetric(double weight, {double? bodyFat}) async {
    final newMetric = BodyMetric(
      date: DateTime.now(),
      weight: weight.toString(),
      bodyFat: bodyFat?.toString() ?? '',
    );

    final updatedMetrics = [newMetric, ...state.metrics];
    state = state.copyWith(metrics: updatedMetrics);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _metricsKey,
      json.encode(updatedMetrics.map((x) => x.toMap()).toList()),
    );
  }

  Future<void> deleteBodyMetric(int index) async {
    final updatedMetrics = List<BodyMetric>.from(state.metrics);
    updatedMetrics.removeAt(index);

    state = state.copyWith(metrics: updatedMetrics);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _metricsKey,
      json.encode(updatedMetrics.map((x) => x.toMap()).toList()),
    );
  }

  Future<void> addProgressPhoto(String path) async {
    final updated = [
      ProgressPhoto(
          id: const Uuid().v4(), date: DateTime.now(), imagePath: path),
      ...state.photos
    ];
    state = state.copyWith(photos: updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _photosKey, json.encode(updated.map((x) => x.toMap()).toList()));
  }

  Future<void> deleteProgressPhoto(String id) async {
    final updatedPhotos = state.photos.where((p) => p.id != id).toList();

    state = state.copyWith(photos: updatedPhotos);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _photosKey,
      json.encode(updatedPhotos.map((x) => x.toMap()).toList()),
    );
  }

  Future<void> clearAllData() async {
    state = TrackerState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_metricsKey);
    await prefs.remove(_photosKey);
  }

  Map<String, double> getPersonalRecords(List<Exercise> all) {
    double b = 0, s = 0, d = 0;
    for (final w in state.history) {
      for (final liveEx in w.routine) {
        if (!liveEx.tracksWeight) continue;
        final matches = all.where((e) => e.id == liveEx.exerciseId);
        if (matches.isEmpty) continue;
        final ex = matches.first;
        final name = ex.name.toLowerCase();
        for (final set in liveEx.sets.where((s) => s.isWorking)) {
          double weight = double.tryParse(set.weight) ?? 0;
          if (name.contains("bench press") && weight > b) b = weight;
          if (name.contains("squat") && !name.contains("split") && weight > s)
            s = weight;
          if (name.contains("deadlift") && weight > d) d = weight;
        }
      }
    }
    return {'Bench': b, 'Squat': s, 'Deadlift': d};
  }
}
