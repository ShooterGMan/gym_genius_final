import 'dart:convert';
import 'package:flutter/material.dart';

enum WorkoutCategory {
  strength,
  hypertrophy,
  endurance,
  weightLoss,
  fullBody,
  upperLower,
  ppl,
  broSplit
}

enum Difficulty { beginner, intermediate, advanced }

class PlannedExercise {
  final String exerciseId;
  final int sets;
  final String reps;
  final String? notes;
  final int? restSeconds;

  PlannedExercise({
    required this.exerciseId,
    this.sets = 3,
    this.reps = '10',
    this.notes,
    this.restSeconds,
  });

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'sets': sets,
        'reps': reps,
        'notes': notes,
        'restSeconds': restSeconds,
      };

  factory PlannedExercise.fromMap(Map<String, dynamic> map) => PlannedExercise(
        exerciseId: map['exerciseId'] ?? '',
        sets: map['sets'] ?? 3,
        reps: map['reps'] ?? '10',
        notes: map['notes'],
        restSeconds: map['restSeconds'],
      );

  PlannedExercise copyWith({
    String? exerciseId,
    int? sets,
    String? reps,
    String? notes,
    int? restSeconds,
  }) =>
      PlannedExercise(
        exerciseId: exerciseId ?? this.exerciseId,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        notes: notes ?? this.notes,
        restSeconds: restSeconds ?? this.restSeconds,
      );
}

class WorkoutRoutine {
  final String id;
  final String name;
  final List<PlannedExercise> exercises;
  final String? notes;

  WorkoutRoutine({
    required this.id,
    required this.name,
    required this.exercises,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'notes': notes,
      };

  factory WorkoutRoutine.fromMap(Map<String, dynamic> map) => WorkoutRoutine(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        exercises: (map['exercises'] as List)
            .map((e) => PlannedExercise.fromMap(e))
            .toList(),
        notes: map['notes'],
      );

  WorkoutRoutine copyWith({
    String? id,
    String? name,
    List<PlannedExercise>? exercises,
    String? notes,
  }) =>
      WorkoutRoutine(
        id: id ?? this.id,
        name: name ?? this.name,
        exercises: exercises ?? this.exercises,
        notes: notes ?? this.notes,
      );

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets);
}

class Program {
  final String id;
  final String name;
  final String description;
  final String coverImage;
  final String? customCoverImage;
  final Difficulty difficulty;
  final List<WorkoutCategory> categories;
  final List<String> equipment;
  final int estimatedWeeks;
  final List<WorkoutRoutine> routines;
  final String? author;
  final bool isCustom;
  final bool isImported;
  final String? importedFrom;
  final DateTime createdAt;
  final DateTime updatedAt;

  Program({
    required this.id,
    required this.name,
    required this.description,
    required this.coverImage,
    this.customCoverImage,
    required this.difficulty,
    required this.categories,
    required this.equipment,
    this.estimatedWeeks = 4,
    required this.routines,
    this.author,
    this.isCustom = false,
    this.isImported = false,
    this.importedFrom,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'coverImage': coverImage,
        'customCoverImage': customCoverImage,
        'difficulty': difficulty.name,
        'categories': categories.map((c) => c.name).toList(),
        'equipment': equipment,
        'estimatedWeeks': estimatedWeeks,
        'routines': routines.map((r) => r.toMap()).toList(),
        'author': author,
        'isCustom': isCustom,
        'isImported': isImported,
        'importedFrom': importedFrom,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Program.fromMap(Map<String, dynamic> map) => Program(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        coverImage: map['coverImage'] ?? '',
        customCoverImage: map['customCoverImage'],
        difficulty: Difficulty.values.firstWhere(
          (d) => d.name == map['difficulty'],
          orElse: () => Difficulty.intermediate,
        ),
        categories: (map['categories'] as List? ?? [])
            .map((c) => WorkoutCategory.values.firstWhere(
                  (wc) => wc.name == c,
                  orElse: () => WorkoutCategory.fullBody,
                ))
            .toList(),
        equipment: List<String>.from(map['equipment'] ?? []),
        estimatedWeeks: map['estimatedWeeks'] ?? 4,
        routines: (map['routines'] as List? ?? [])
            .map((r) => WorkoutRoutine.fromMap(r))
            .toList(),
        author: map['author'],
        isCustom: map['isCustom'] ?? false,
        isImported: map['isImported'] ?? false,
        importedFrom: map['importedFrom'],
        createdAt:
            map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
        updatedAt:
            map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      );

  String toJson() => json.encode(toMap());
  factory Program.fromJson(String source) =>
      Program.fromMap(json.decode(source));

  Program copyWith({
    String? id,
    String? name,
    String? description,
    String? coverImage,
    String? customCoverImage,
    Difficulty? difficulty,
    List<WorkoutCategory>? categories,
    List<String>? equipment,
    int? estimatedWeeks,
    List<WorkoutRoutine>? routines,
    String? author,
    bool? isCustom,
    bool? isImported,
    String? importedFrom,
  }) =>
      Program(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        coverImage: coverImage ?? this.coverImage,
        customCoverImage: customCoverImage ?? this.customCoverImage,
        difficulty: difficulty ?? this.difficulty,
        categories: categories ?? this.categories,
        equipment: equipment ?? this.equipment,
        estimatedWeeks: estimatedWeeks ?? this.estimatedWeeks,
        routines: routines ?? this.routines,
        author: author ?? this.author,
        isCustom: isCustom ?? this.isCustom,
        isImported: isImported ?? this.isImported,
        importedFrom: importedFrom ?? this.importedFrom,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  // Helper getters
  String get displayImage => customCoverImage ?? coverImage;
  int get totalWorkouts => routines.length;
  int get totalExercises =>
      routines.fold(0, (sum, r) => sum + r.exercises.length);
  int get totalSets => routines.fold(0, (sum, r) => sum + r.totalSets);
  String get difficultyLabel =>
      difficulty.name[0].toUpperCase() + difficulty.name.substring(1);
  String get categoriesLabel => categories.map((c) {
        switch (c) {
          case WorkoutCategory.weightLoss:
            return 'Weight Loss';
          case WorkoutCategory.fullBody:
            return 'Full Body';
          case WorkoutCategory.upperLower:
            return 'Upper/Lower';
          case WorkoutCategory.ppl:
            return 'PPL';
          case WorkoutCategory.broSplit:
            return 'Bro Split';
          default:
            return c.name[0].toUpperCase() + c.name.substring(1);
        }
      }).join(' • ');

  // Difficulty color
  Color get difficultyColor {
    switch (difficulty) {
      case Difficulty.beginner:
        return const Color(0xFF4CAF50);
      case Difficulty.intermediate:
        return const Color(0xFFFF9800);
      case Difficulty.advanced:
        return const Color(0xFFF44336);
    }
  }

  // Estimated duration
  String get estimatedDuration {
    final avgSetsPerWorkout =
        routines.isEmpty ? 0 : totalSets ~/ routines.length;
    final estimatedMins = avgSetsPerWorkout * 3;
    return '$estimatedMins min/workout';
  }
}
