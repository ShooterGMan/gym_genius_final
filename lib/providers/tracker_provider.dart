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

  CompletedWorkout(
      {required this.id,
      required this.date,
      required this.durationSeconds,
      required this.totalVolume,
      required this.routine});

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'duration': durationSeconds,
        'volume': totalVolume,
        'routine': routine
            .map((ex) => {
                  'exId': ex.exerciseId,
                  'mode': ex.logMode.index,
                  'sets':
                      ex.sets.map((s) => {'w': s.weight, 'r': s.reps}).toList(),
                })
            .toList(),
      };

  factory CompletedWorkout.fromMap(Map<String, dynamic> map) =>
      CompletedWorkout(
        id: map['id'],
        date: DateTime.parse(map['date']),
        durationSeconds: map['duration'],
        totalVolume: (map['volume'] as num).toDouble(),
        routine: (map['routine'] as List)
            .map((ex) => WorkoutExerciseLive(
                  id: const Uuid().v4(),
                  exerciseId: ex['exId'],
                  logMode: LogMode.values[ex['mode'] ?? 0],
                  sets: (ex['sets'] as List)
                      .map((s) => LiveSet(
                          id: const Uuid().v4(),
                          weight: s['w'],
                          reps: s['r'],
                          isCompleted: true))
                      .toList(),
                ))
            .toList(),
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

    List<CompletedWorkout> h = [];
    List<BodyMetric> m = [];
    List<ProgressPhoto> p = [];
    if (hStr != null)
      h = (json.decode(hStr) as List)
          .map((x) => CompletedWorkout.fromMap(x))
          .toList();
    if (mStr != null)
      m = (json.decode(mStr) as List)
          .map((x) => BodyMetric.fromMap(x))
          .toList();
    if (pStr != null)
      p = (json.decode(pStr) as List)
          .map((x) => ProgressPhoto.fromMap(x))
          .toList();
    state = TrackerState(history: h, metrics: m, photos: p);
  }

  Future<void> saveWorkout(ActiveWorkoutState session) async {
    double calcVolume = 0;
    for (final ex in session.routine) {
      for (final set in ex.sets) {
        if (set.isCompleted)
          calcVolume += (double.tryParse(set.weight) ?? 0) *
              (double.tryParse(set.reps) ?? 0);
      }
    }
    final newWorkout = CompletedWorkout(
        id: const Uuid().v4(),
        date: DateTime.now(),
        durationSeconds: session.elapsedSeconds,
        totalVolume: calcVolume,
        routine: session.routine.map((ex) => ex.copy()).toList());
    final updatedHistory = [newWorkout, ...state.history];
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
        final ex = all.firstWhere((e) => e.id == liveEx.exerciseId,
            orElse: () => all.first);
        final name = ex.name.toLowerCase();
        for (final set in liveEx.sets) {
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
