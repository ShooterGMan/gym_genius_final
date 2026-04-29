import 'dart:convert';
import 'package:flutter/foundation.dart'; // Required for compute
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise.dart';

// Top-level function for the isolate
List<Exercise> _parseExercises(String jsonStr) {
  final List<dynamic> data = json.decode(jsonStr);
  return data.map((json) => Exercise.fromJson(json)).toList();
}

final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final String response = await rootBundle.loadString('assets/exercises.json');
  // Offload parsing to a background thread
  return compute(_parseExercises, response);
});
