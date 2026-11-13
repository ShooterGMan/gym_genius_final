import 'dart:convert';
import 'package:flutter/foundation.dart'; // Required for compute
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';

// Top-level function for the isolate
List<Exercise> _parseExercises(String jsonStr) {
  final List<dynamic> data = json.decode(jsonStr);
  return data.map((json) => Exercise.fromJson(json)).toList();
}

class ExercisesNotifier extends AsyncNotifier<List<Exercise>> {
  static const _customExercisesKey = 'custom_exercises_v1';

  @override
  Future<List<Exercise>> build() async {
    // 1. Load static exercises from assets
    final String response = await rootBundle.loadString('assets/exercises.json');
    final staticExercises = await compute(_parseExercises, response);

    // 2. Load custom exercises from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final customExercisesStr = prefs.getString(_customExercisesKey);
    if (customExercisesStr != null) {
      try {
        final List<dynamic> data = json.decode(customExercisesStr);
        final customExercises = data.map((json) => Exercise.fromJson(json)).toList();
        return [...staticExercises, ...customExercises];
      } catch (e) {
        debugPrint('Error parsing custom exercises: $e');
      }
    }

    return staticExercises;
  }

  Future<void> addCustomExercise(Exercise exercise) async {
    final currentList = state.value ?? [];
    
    // We append the new exercise to our in-memory list
    state = AsyncValue.data([...currentList, exercise]);

    // Save custom exercises to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final customExercisesStr = prefs.getString(_customExercisesKey);
    
    List<Exercise> customList = [];
    if (customExercisesStr != null) {
      try {
        final List<dynamic> data = json.decode(customExercisesStr);
        customList = data.map((json) => Exercise.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error parsing existing custom exercises for saving: $e');
      }
    }
    
    customList.add(exercise);
    
    await prefs.setString(
      _customExercisesKey,
      json.encode(customList.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearCustomExercises() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customExercisesKey);
    ref.invalidateSelf();
  }
}

final exercisesProvider = AsyncNotifierProvider<ExercisesNotifier, List<Exercise>>(() {
  return ExercisesNotifier();
});
