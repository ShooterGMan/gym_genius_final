import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../providers/program_provider.dart';
import '../providers/exercise_provider.dart';
import '../models/exercise.dart';
import '../models/program.dart';
import '../theme/app_theme.dart';

class ProgramCreatorScreen extends ConsumerStatefulWidget {
  final String? editProgramId;
  final String? initialExerciseId;

  const ProgramCreatorScreen(
      {super.key, this.editProgramId, this.initialExerciseId});

  @override
  ConsumerState<ProgramCreatorScreen> createState() =>
      _ProgramCreatorScreenState();
}

class _ProgramCreatorScreenState extends ConsumerState<ProgramCreatorScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  Difficulty _difficulty = Difficulty.intermediate;
  List<WorkoutRoutine> _routines = [];
  bool _isInit = false;
  Program? _editing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final matches = widget.editProgramId == null
          ? const <Program>[]
          : ref
              .read(programProvider)
              .customPrograms
              .where((p) => p.id == widget.editProgramId)
              .toList();
      if (matches.isNotEmpty) {
        final p = matches.first;
        _editing = p;
        _nameController.text = p.name;
        _descriptionController.text = p.description;
        _difficulty = p.difficulty;
        _routines = List.from(p.routines);
      } else {
        // Add first empty day
        _routines.add(WorkoutRoutine(
          id: const Uuid().v4(),
          name: 'Workout 1',
          exercises: [
            // "Create new program" from an exercise's sheet starts with it.
            if (widget.initialExerciseId != null &&
                widget.initialExerciseId!.isNotEmpty)
              PlannedExercise(exerciseId: widget.initialExerciseId!),
          ],
        ));
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addDay() => setState(() => _routines.add(WorkoutRoutine(
      id: const Uuid().v4(),
      name: 'Workout ${_routines.length + 1}',
      exercises: [])));

  void _removeDay(int index) {
    if (_routines.length > 1) {
      setState(() => _routines.removeAt(index));
    }
  }

  void _removeExercise(int dayIndex, int exerciseIndex) {
    setState(() {
      final updatedExercises =
          List<PlannedExercise>.from(_routines[dayIndex].exercises);
      updatedExercises.removeAt(exerciseIndex);
      _routines[dayIndex] = WorkoutRoutine(
        id: _routines[dayIndex].id,
        name: _routines[dayIndex].name,
        exercises: updatedExercises,
        notes: _routines[dayIndex].notes,
      );
    });
  }

  void _addExerciseToDay(int dayIndex, String exerciseId) {
    setState(() {
      final updatedExercises =
          List<PlannedExercise>.from(_routines[dayIndex].exercises)
            ..add(PlannedExercise(exerciseId: exerciseId));
      _routines[dayIndex] = WorkoutRoutine(
        id: _routines[dayIndex].id,
        name: _routines[dayIndex].name,
        exercises: updatedExercises,
        notes: _routines[dayIndex].notes,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(exercisesProvider).value ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: const Text("PROGRAM BUILDER"),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          actions: [
            TextButton(
                onPressed: _save,
                child: const Text("SAVE",
                    style: TextStyle(color: AppColors.accent)))
          ]),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        TextField(
            controller: _nameController,
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
                hintText: "Program Name", border: InputBorder.none)),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: "Description (optional)",
            hintStyle: TextStyle(color: Colors.white24),
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 16),
        // Difficulty selector
        Row(
          children: ['Beginner', 'Intermediate', 'Advanced'].map((level) {
            final diff = level == 'Beginner'
                ? Difficulty.beginner
                : level == 'Intermediate'
                    ? Difficulty.intermediate
                    : Difficulty.advanced;
            final isSelected = _difficulty == diff;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(level,
                    style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                selected: isSelected,
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                    color: isSelected ? AppColors.accent : AppColors.border),
                onSelected: (_) => setState(() => _difficulty = diff),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        ..._routines
            .asMap()
            .entries
            .map((entry) => _buildDay(entry.key, entry.value, db)),
        ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.all(20)),
            onPressed: _addDay,
            icon: const Icon(Icons.add, color: AppColors.accent),
            label: const Text("ADD TRAINING DAY")),
        const SizedBox(height: 100),
      ]),
    );
  }

  Widget _buildDay(int idx, WorkoutRoutine routine, List<Exercise> db) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Day header with delete button
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey(routine.id),
                initialValue: routine.name,
                onChanged: (v) => setState(() {
                  final updatedRoutines = List<WorkoutRoutine>.from(_routines);
                  updatedRoutines[idx] = WorkoutRoutine(
                    id: routine.id,
                    name: v,
                    exercises: routine.exercises,
                    notes: routine.notes,
                  );
                  _routines = updatedRoutines;
                }),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
                decoration: const InputDecoration(
                    border: InputBorder.none, hintText: "Routine Name"),
              ),
            ),
            if (_routines.length > 1)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text("Delete Day?",
                          style: TextStyle(color: Colors.white)),
                      content: Text(
                          "Remove '${routine.name}' from this program?",
                          style: const TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel",
                              style: TextStyle(color: Colors.white70)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _removeDay(idx);
                          },
                          child: const Text("Delete",
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'Remove day',
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Exercises list
        ...routine.exercises.asMap().entries.map((entry) {
          final exerciseIndex = entry.key;
          final planned = entry.value;
          final ex = db.firstWhere((e) => e.id == planned.exerciseId,
              orElse: () => Exercise(
                  id: planned.exerciseId,
                  name: "Exercise not found",
                  category: '',
                  equipment: '',
                  images: [],
                  instructions: [],
                  primaryMuscles: [],
                  secondaryMuscles: [],
                  level: ''));

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.black12, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              // Exercise name + remove button
              Row(children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ex.images.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/${ex.images[0].replaceAll('/', '_')}',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.fitness_center,
                                    color: Colors.white24, size: 20),
                          ),
                        )
                      : const Icon(Icons.fitness_center,
                          color: Colors.white24, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(ex.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14))),
                IconButton(
                    icon: const Icon(Icons.close,
                        size: 16, color: Colors.redAccent),
                    onPressed: () => _removeExercise(idx, exerciseIndex),
                    tooltip: 'Remove exercise'),
              ]),
              const SizedBox(height: 8),
              // Sets and Reps inputs
              Row(children: [
                _miniInput("Sets", planned.sets.toString(), ValueKey('${routine.id}_${exerciseIndex}_sets'), (v) {
                  setState(() {
                    final updatedExercises =
                        List<PlannedExercise>.from(routine.exercises);
                    updatedExercises[exerciseIndex] = PlannedExercise(
                        exerciseId: planned.exerciseId,
                        sets: int.tryParse(v) ?? 1,
                        reps: planned.reps,
                        notes: planned.notes,
                        restSeconds: planned.restSeconds);
                    final updatedRoutines =
                        List<WorkoutRoutine>.from(_routines);
                    updatedRoutines[idx] = WorkoutRoutine(
                      id: routine.id,
                      name: routine.name,
                      exercises: updatedExercises,
                      notes: routine.notes,
                    );
                    _routines = updatedRoutines;
                  });
                }),
                const SizedBox(width: 12),
                _miniInput("Reps", planned.reps, ValueKey('${routine.id}_${exerciseIndex}_reps'), (v) {
                  setState(() {
                    final updatedExercises =
                        List<PlannedExercise>.from(routine.exercises);
                    updatedExercises[exerciseIndex] = PlannedExercise(
                        exerciseId: planned.exerciseId,
                        sets: planned.sets,
                        reps: v,
                        notes: planned.notes,
                        restSeconds: planned.restSeconds);
                    final updatedRoutines =
                        List<WorkoutRoutine>.from(_routines);
                    updatedRoutines[idx] = WorkoutRoutine(
                      id: routine.id,
                      name: routine.name,
                      exercises: updatedExercises,
                      notes: routine.notes,
                    );
                    _routines = updatedRoutines;
                  });
                }),
              ]),
            ]),
          );
        }).toList(),
        // Add exercise button
        TextButton.icon(
            onPressed: () async {
              final res = await context.push<String>('/pick-exercise');
              if (res != null && mounted) {
                _addExerciseToDay(idx, res);
              }
            },
            icon: const Icon(Icons.add, size: 16, color: AppColors.accent),
            label: const Text("ADD EXERCISE",
                style: TextStyle(color: AppColors.accent, fontSize: 12))),
      ]),
    );
  }

  Widget _miniInput(String l, String v, Key key, Function(String) onTyped) => Expanded(
      child: TextFormField(
          key: key,
          initialValue: v,
          onChanged: onTyped,
          style: const TextStyle(color: AppColors.accent, fontSize: 12),
          decoration: InputDecoration(
              labelText: l,
              labelStyle:
                  const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              isDense: true,
              border: InputBorder.none)));

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a program name."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_routines.every((r) => r.exercises.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Add at least one exercise to a workout day."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Drop empty days so they never become un-startable routines.
    final routines = _routines.where((r) => r.exercises.isNotEmpty).toList();
    final existing = _editing;

    final program = Program(
      id: existing?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      // Keep the original cover/categories/equipment when editing (e.g. an
      // imported program) instead of overwriting them with defaults.
      coverImage: existing?.coverImage ??
          'assets/workout_covers/workouts/strength_foundation.jpg',
      customCoverImage: existing?.customCoverImage,
      difficulty: _difficulty,
      categories: existing?.categories ?? [WorkoutCategory.fullBody],
      equipment: existing?.equipment ?? const [],
      estimatedWeeks: existing?.estimatedWeeks ?? 4,
      routines: routines,
      author: existing?.author,
      isCustom: true,
    );

    if (existing != null) {
      ref.read(programProvider.notifier).updateProgram(program);
    } else {
      ref.read(programProvider.notifier).createProgram(program);
    }
    context.pop();
  }
}
