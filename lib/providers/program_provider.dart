import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../models/program.dart';

class ProgramState {
  final List<Program> popularPrograms;
  final List<Program> customPrograms;
  final String? activeProgramId;
  final int currentRoutineIndex;
  final bool isLoading;
  final String? error;

  ProgramState({
    this.popularPrograms = const [],
    this.customPrograms = const [],
    this.activeProgramId,
    this.currentRoutineIndex = 0,
    this.isLoading = false,
    this.error,
  });

  ProgramState copyWith({
    List<Program>? popularPrograms,
    List<Program>? customPrograms,
    String? activeProgramId,
    int? currentRoutineIndex,
    bool? isLoading,
    String? error,
  }) =>
      ProgramState(
        popularPrograms: popularPrograms ?? this.popularPrograms,
        customPrograms: customPrograms ?? this.customPrograms,
        activeProgramId: activeProgramId ?? this.activeProgramId,
        currentRoutineIndex: currentRoutineIndex ?? this.currentRoutineIndex,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  List<Program> get allPrograms => [...popularPrograms, ...customPrograms];

  Program? get activeProgram {
    if (activeProgramId == null) return null;
    return allPrograms.firstWhere(
      (p) => p.id == activeProgramId,
      orElse: () => allPrograms.first,
    );
  }
}

final programProvider = NotifierProvider<ProgramNotifier, ProgramState>(() {
  return ProgramNotifier();
});

class ProgramNotifier extends Notifier<ProgramState> {
  static const String _storageKey = 'user_programs_v4';
  static const String _activeKey = 'active_program_v2';
  static const String _indexKey = 'program_index_v2';
  final _uuid = const Uuid();

  @override
  ProgramState build() {
    debugPrint('🔄 ProgramNotifier.build() called');
    Future.microtask(() => _loadAllData());
    return ProgramState(
        isLoading: true, popularPrograms: [], customPrograms: []);
  }

  Future<void> _loadAllData() async {
    debugPrint('📂 _loadAllData() started');
    try {
      // Load popular programs from JSON
      final popularJson =
          await rootBundle.loadString('assets/popular_workouts.json');
      final List<dynamic> popularList = json.decode(popularJson);
      final popular = popularList.map((p) => Program.fromMap(p)).toList();
      debugPrint('✅ Loaded ${popular.length} popular programs');

      // Load custom programs from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final customJson = prefs.getString(_storageKey);
      List<Program> custom = [];

      debugPrint('📦 Raw customJson from SharedPreferences: $customJson');

      if (customJson != null && customJson.isNotEmpty) {
        try {
          final List<dynamic> customList = json.decode(customJson);
          debugPrint('📋 Decoded customList length: ${customList.length}');
          custom = customList.map((p) {
            debugPrint('🔄 Parsing program: ${p['name']}');
            return Program.fromMap(p);
          }).toList();
          debugPrint('✅ Loaded ${custom.length} custom programs');
        } catch (e) {
          debugPrint('❌ Error parsing custom programs: $e');
        }
      } else {
        debugPrint('⚠️ No custom programs found in SharedPreferences');
      }

      // Load active program
      final activeId = prefs.getString(_activeKey);
      final routineIndex = prefs.getInt(_indexKey) ?? 0;

      state = ProgramState(
        popularPrograms: popular,
        customPrograms: custom,
        activeProgramId: activeId,
        currentRoutineIndex: routineIndex,
        isLoading: false,
      );

      debugPrint(
          '✅ State updated: ${custom.length} custom, ${popular.length} popular');
    } catch (e) {
      debugPrint('❌ Error loading programs: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> reloadPopularPrograms() async {
    try {
      final popularJson =
          await rootBundle.loadString('assets/popular_workouts.json');
      final List<dynamic> popularList = json.decode(popularJson);
      final popular = popularList.map((p) => Program.fromMap(p)).toList();

      state = state.copyWith(
        popularPrograms: popular,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ Error loading popular programs: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _saveCustomPrograms() async {
    debugPrint('💾 _saveCustomPrograms() called');
    debugPrint(
        '📊 Current custom programs count: ${state.customPrograms.length}');

    final prefs = await SharedPreferences.getInstance();

    // Convert to JSON
    final List<Map<String, dynamic>> programMaps = [];
    for (var p in state.customPrograms) {
      try {
        final map = p.toMap();
        programMaps.add(map);
        debugPrint('  ✅ Mapped program: ${p.name}');
      } catch (e) {
        debugPrint('  ❌ Failed to map program ${p.name}: $e');
      }
    }

    final encoded = json.encode(programMaps);
    debugPrint('📝 Encoded JSON length: ${encoded.length}');

    final success = await prefs.setString(_storageKey, encoded);
    debugPrint('💾 Saved to SharedPreferences: $success');

    // Verify save
    final verify = prefs.getString(_storageKey);
    debugPrint(
        '🔍 Verification read: ${verify != null ? "success" : "failed"}');
    if (verify != null) {
      debugPrint('🔍 Verification length: ${verify.length}');
    }
  }

  Future<void> _saveActiveState() async {
    final prefs = await SharedPreferences.getInstance();
    if (state.activeProgramId != null) {
      await prefs.setString(_activeKey, state.activeProgramId!);
      await prefs.setInt(_indexKey, state.currentRoutineIndex);
    }
  }

  Future<void> importProgram(String programId) async {
    debugPrint('📥 importProgram() called with ID: $programId');
    try {
      final popular = state.popularPrograms.firstWhere(
        (p) => p.id == programId,
        orElse: () => throw Exception('Program not found'),
      );
      debugPrint('✅ Found popular program: ${popular.name}');

      // Check if already imported
      final alreadyImported = state.customPrograms.any(
        (p) =>
            p.importedFrom == programId ||
            (p.name == popular.name && p.isImported),
      );

      if (alreadyImported) {
        debugPrint('⚠️ Program already imported: ${popular.name}');
        return;
      }

      // Create new routines with new IDs
      final newRoutines = popular.routines.map((r) {
        debugPrint(
            '  📋 Creating routine: ${r.name} with ${r.exercises.length} exercises');
        return WorkoutRoutine(
          id: _uuid.v4(),
          name: r.name,
          exercises: r.exercises
              .map((e) => PlannedExercise(
                    exerciseId: e.exerciseId,
                    sets: e.sets,
                    reps: e.reps,
                    notes: e.notes,
                    restSeconds: e.restSeconds,
                  ))
              .toList(),
          notes: r.notes,
        );
      }).toList();

      final imported = Program(
        id: _uuid.v4(),
        name: popular.name,
        description: popular.description,
        coverImage: popular.coverImage,
        difficulty: popular.difficulty,
        categories: popular.categories,
        equipment: popular.equipment,
        estimatedWeeks: popular.estimatedWeeks,
        routines: newRoutines,
        author: popular.author,
        isCustom: true,
        isImported: true,
        importedFrom: popular.id,
        createdAt: DateTime.now(),
      );

      debugPrint('📦 Created imported program with ID: ${imported.id}');

      final newCustomPrograms = [...state.customPrograms, imported];
      debugPrint('📊 New custom programs count: ${newCustomPrograms.length}');

      state = state.copyWith(customPrograms: newCustomPrograms);

      await _saveCustomPrograms();

      debugPrint('✅ Successfully imported program: ${popular.name}');
    } catch (e, stackTrace) {
      debugPrint('❌ Error importing program: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> createProgram(Program program) async {
    debugPrint('📝 createProgram() called with name: ${program.name}');

    final newProgram = program.copyWith(
      id: program.id.isEmpty ? _uuid.v4() : program.id,
      isCustom: true,
    );

    debugPrint('📦 Created program with ID: ${newProgram.id}');

    final newCustomPrograms = [...state.customPrograms, newProgram];
    debugPrint('📊 New custom programs count: ${newCustomPrograms.length}');

    state = state.copyWith(customPrograms: newCustomPrograms);
    await _saveCustomPrograms();

    debugPrint('✅ Program created successfully');
  }

  Future<void> updateProgram(Program program) async {
    final updatedList = state.customPrograms.map((p) {
      if (p.id == program.id) {
        return Program(
          id: p.id,
          name: program.name,
          description: program.description,
          coverImage: program.coverImage,
          customCoverImage: program.customCoverImage,
          difficulty: program.difficulty,
          categories: program.categories,
          equipment: program.equipment,
          estimatedWeeks: program.estimatedWeeks,
          routines: program.routines,
          author: program.author,
          isCustom: p.isCustom,
          isImported: p.isImported,
          importedFrom: p.importedFrom,
          createdAt: p.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      return p;
    }).toList();

    state = state.copyWith(customPrograms: updatedList);
    await _saveCustomPrograms();
  }

  Future<void> deleteProgram(String id) async {
    state = state.copyWith(
      customPrograms: state.customPrograms.where((p) => p.id != id).toList(),
    );

    if (state.activeProgramId == id) {
      state = state.copyWith(activeProgramId: null);
    }

    await _saveCustomPrograms();
    await _saveActiveState();
  }

  void setActiveProgram(String id) {
    state = state.copyWith(
      activeProgramId: id,
      currentRoutineIndex: 0,
    );
    _saveActiveState();
  }

  void clearActiveProgram() {
    state = state.copyWith(activeProgramId: null);
    _saveActiveState();
  }

  void setCurrentRoutineIndex(int index) {
    state = state.copyWith(currentRoutineIndex: index);
    _saveActiveState();
  }

  void nextRoutine() {
    final program = state.activeProgram;
    if (program != null) {
      final nextIndex =
          (state.currentRoutineIndex + 1) % program.routines.length;
      setCurrentRoutineIndex(nextIndex);
    }
  }

  List<Program> filterProgramsByEquipment(List<String> availableEquipment) {
    if (availableEquipment.isEmpty) return state.popularPrograms;

    return state.popularPrograms.where((program) {
      return program.equipment.every((eq) => availableEquipment.any((avail) =>
          eq.toLowerCase().contains(avail.toLowerCase()) ||
          avail.toLowerCase().contains(eq.toLowerCase())));
    }).toList();
  }

  List<Program> getProgramsByCategory(WorkoutCategory category) {
    return state.popularPrograms
        .where((p) => p.categories.contains(category))
        .toList();
  }

  // Debug method to clear all data
  Future<void> debugClearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_activeKey);
    await prefs.remove(_indexKey);
    state = state.copyWith(customPrograms: [], activeProgramId: null);
    debugPrint('🧹 Cleared all program data');
  }

  // Debug method to print current state
  void debugPrintState() {
    debugPrint('📊 === PROGRAM STATE ===');
    debugPrint('📊 Popular programs: ${state.popularPrograms.length}');
    debugPrint('📊 Custom programs: ${state.customPrograms.length}');
    for (var p in state.customPrograms) {
      debugPrint('  - ${p.name} (ID: ${p.id}, Imported: ${p.isImported})');
    }
    debugPrint('📊 Active program: ${state.activeProgramId}');
    debugPrint('📊 Is loading: ${state.isLoading}');
    debugPrint('📊 Error: ${state.error}');
    debugPrint('📊 ====================');
  }
}
