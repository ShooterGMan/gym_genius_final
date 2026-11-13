import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/pr_tracker_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/settings_provider.dart';
import '../models/exercise.dart';
import '../theme/app_theme.dart';

class PRTrackerScreen extends ConsumerWidget {
  const PRTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(settingsProvider).weightUnit;
    final prState = ref.watch(prTrackerProvider);
    final exercises = ref.watch(exercisesProvider).value ?? [];
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _AddPRBottomSheet(exercises: exercises),
          );
        },
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                isSmallScreen ? 16 : 24,
                isSmallScreen ? 12 : 16,
                isSmallScreen ? 16 : 24,
                8,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left,
                        color: Colors.white, size: isSmallScreen ? 28 : 32),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      "PERSONAL RECORDS",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 18 : 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    // Tab bar
                    Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                      ),
                      child: TabBar(
                        indicatorColor: AppColors.accent,
                        labelColor: AppColors.accent,
                        unselectedLabelColor: Colors.white38,
                        dividerColor: Colors.transparent,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: isSmallScreen ? 10 : 12,
                          letterSpacing: 1,
                        ),
                        tabs: const [
                          Tab(text: "HEAVIEST"),
                          Tab(text: "MOST REPS"),
                          Tab(text: "VOLUME"),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildPRList(prState.heaviestWeight, exercises, 'weight', isSmallScreen, unit),
                          _buildPRList(prState.mostReps, exercises, 'reps', isSmallScreen, unit),
                          _buildPRList(prState.highestVolume, exercises, 'volume', isSmallScreen, unit),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPRList(
    Map<String, PersonalRecord> records,
    List<Exercise> exercises,
    String category,
    bool isSmallScreen,
    String unit,
  ) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: isSmallScreen ? 56 : 64,
              color: Colors.white24,
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            Text(
              "No records yet",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: isSmallScreen ? 15 : 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 10),
            Text(
              "Complete workouts to start\ntracking your records!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ],
        ),
      );
    }

    // Sort by weight/reps/volume descending
    final sortedEntries = records.entries.toList()
      ..sort((a, b) {
        if (category == 'weight') return b.value.weight.compareTo(a.value.weight);
        if (category == 'reps') return b.value.reps.compareTo(a.value.reps);
        return b.value.volume.compareTo(a.value.volume);
      });

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: isSmallScreen ? 12 : 16,
      ),
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        final pr = entry.value;
        final exercise = exercises.firstWhere(
          (e) => e.id == pr.exerciseId,
          orElse: () => Exercise(
            id: pr.exerciseId,
            name: pr.exerciseName,
            equipment: '',
            level: '',
            primaryMuscles: [],
            secondaryMuscles: [],
            category: '',
            images: [],
            instructions: [],
          ),
        );

        return _buildPRCard(pr, exercise, index + 1, category, isSmallScreen, unit);
      },
    );
  }

  Widget _buildPRCard(
    PersonalRecord pr,
    Exercise exercise,
    int rank,
    String category,
    bool isSmallScreen,
    String unit,
  ) {
    // Medal colors for top 3
    Color? rankColor;
    IconData? rankIcon;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = Icons.emoji_events;
    }

    // Exercise image
    final imagePath = exercise.images.isNotEmpty
        ? 'assets/images/${exercise.images[0].replaceAll('/', '_')}'
        : '';

    // Display value based on category
    String displayValue;
    String displayUnit;
    if (category == 'weight') {
      displayValue = '${pr.weight.toStringAsFixed(pr.weight == pr.weight.toInt() ? 0 : 1)}';
      displayUnit = unit;
    } else if (category == 'reps') {
      displayValue = '${pr.reps}';
      displayUnit = 'reps';
    } else {
      displayValue = '${pr.volume.toStringAsFixed(0)}';
      displayUnit = '$unit total';
    }

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 14),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        border: Border.all(
          color: rankColor?.withValues(alpha: 0.3) ?? Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: rankColor != null
            ? [
                BoxShadow(
                  color: rankColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Rank indicator
          Container(
            width: isSmallScreen ? 36 : 42,
            child: rankIcon != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(rankIcon, color: rankColor, size: isSmallScreen ? 22 : 26),
                      SizedBox(height: 2),
                      Text(
                        '#$rank',
                        style: TextStyle(
                          color: rankColor,
                          fontSize: isSmallScreen ? 9 : 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Text(
                    '#$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          SizedBox(width: isSmallScreen ? 10 : 14),

          // Exercise image
          Container(
            height: isSmallScreen ? 44 : 52,
            width: isSmallScreen ? 44 : 52,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              image: imagePath.isNotEmpty
                  ? DecorationImage(
                      image: AssetImage(imagePath),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imagePath.isEmpty
                ? Icon(Icons.fitness_center,
                    color: Colors.white24, size: isSmallScreen ? 20 : 24)
                : null,
          ),
          SizedBox(width: isSmallScreen ? 10 : 14),

          // Exercise info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pr.exerciseName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isSmallScreen ? 3 : 5),
                Text(
                  pr.formattedDate,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: isSmallScreen ? 10 : 12,
                  ),
                ),
                if (category == 'weight') ...[
                  SizedBox(height: 2),
                  Text(
                    '${pr.reps} reps',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: isSmallScreen ? 9 : 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),

          // PR value
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: (rankColor ?? AppColors.accent).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 14),
              border: Border.all(
                color: (rankColor ?? AppColors.accent).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  displayValue,
                  style: TextStyle(
                    color: rankColor ?? AppColors.accent,
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  displayUnit,
                  style: TextStyle(
                    color: (rankColor ?? AppColors.accent).withValues(alpha: 0.7),
                    fontSize: isSmallScreen ? 8 : 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPRBottomSheet extends ConsumerStatefulWidget {
  final List<Exercise> exercises;
  const _AddPRBottomSheet({required this.exercises});

  @override
  ConsumerState<_AddPRBottomSheet> createState() => _AddPRBottomSheetState();
}

class _AddPRBottomSheetState extends ConsumerState<_AddPRBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();

  late Exercise _selectedExercise;
  String _selectedCategory = 'weight'; // 'weight', 'reps', 'volume'
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedExercise = widget.exercises.isNotEmpty
        ? widget.exercises.first
        : Exercise(
            id: 'default',
            name: 'Select Exercise',
            equipment: '',
            level: '',
            primaryMuscles: [],
            secondaryMuscles: [],
            category: '',
            images: [],
            instructions: [],
          );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'LOG PERSONAL RECORD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'EXERCISE',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Exercise>(
                    value: _selectedExercise,
                    dropdownColor: AppColors.surface,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.accent),
                    style: const TextStyle(color: Colors.white),
                    items: widget.exercises.map((ex) {
                      return DropdownMenuItem<Exercise>(
                        value: ex,
                        child: Text(ex.name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedExercise = val;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PR TYPE',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              dropdownColor: AppColors.surface,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.accent),
                              style: const TextStyle(color: Colors.white),
                              items: const [
                                DropdownMenuItem(value: 'weight', child: Text('Heaviest Weight')),
                                DropdownMenuItem(value: 'reps', child: Text('Most Reps')),
                                DropdownMenuItem(value: 'volume', child: Text('Highest Volume')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedCategory = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DATE',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const Icon(Icons.calendar_today, color: AppColors.accent, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WEIGHT (${ref.watch(settingsProvider).weightUnit.toUpperCase()})',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          cursorColor: AppColors.accent,
                          decoration: InputDecoration(
                            hintText: 'e.g. 100',
                            hintStyle: const TextStyle(color: Colors.white30),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.02),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.accent),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REPS',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _repsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: AppColors.accent,
                          decoration: InputDecoration(
                            hintText: 'e.g. 5',
                            hintStyle: const TextStyle(color: Colors.white30),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.02),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.accent),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _savePR,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'SAVE PERSONAL RECORD',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: Colors.black,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _savePR() async {
    if (!_formKey.currentState!.validate()) return;

    final weight = double.parse(_weightController.text.trim());
    final reps = int.parse(_repsController.text.trim());

    final pr = PersonalRecord(
      exerciseId: _selectedExercise.id,
      exerciseName: _selectedExercise.name,
      weight: weight,
      reps: reps,
      date: _selectedDate,
      category: _selectedCategory,
    );

    try {
      await ref.read(manualPRsProvider.notifier).addManualPR(pr);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PR saved for "${_selectedExercise.name}"!',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PR: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}