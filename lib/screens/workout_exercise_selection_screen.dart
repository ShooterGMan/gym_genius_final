import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../providers/favorites_provider.dart';
import '../models/exercise.dart';
import '../theme/app_theme.dart';

class WorkoutExerciseSelectionScreen extends ConsumerStatefulWidget {
  const WorkoutExerciseSelectionScreen({super.key});

  @override
  ConsumerState<WorkoutExerciseSelectionScreen> createState() =>
      _WorkoutExerciseSelectionScreenState();
}

class _WorkoutExerciseSelectionScreenState
    extends ConsumerState<WorkoutExerciseSelectionScreen> {
  String _searchQuery = '';
  String _activeCategory = 'All';
  String _activeEquipment = 'All';

  final List<String> _categoryFilters = [
    'All',
    'Favorites',
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Arms',
    'Core',
    'Cardio'
  ];

  final List<String> _equipmentFilters = [
    'All',
    'Body Weight',
    'Barbell',
    'Dumbbell',
    'Cable',
    'Machine',
    'Band'
  ];

  bool _fuzzyMatch(String text, String query) {
    if (query.isEmpty) return true;

    text = text.toLowerCase();
    query = query.toLowerCase();

    if (text.contains(query)) return true;

    final queryWords = query.split(' ');
    int lastIndex = 0;
    for (final word in queryWords) {
      if (word.isEmpty) continue;
      final index = text.indexOf(word, lastIndex);
      if (index == -1) return false;
      lastIndex = index + word.length;
    }
    return true;
  }

  List<Exercise> _filterExercises(List<Exercise> allExercises) {
    final favorites = ref.watch(favoritesProvider).exerciseIds;

    List<Exercise> categoryFiltered = allExercises.where((ex) {
      if (_activeCategory == 'All') return true;
      
      // Favorites filter
      if (_activeCategory == 'Favorites') {
        return favorites.contains(ex.id);
      }
      
      final query = _activeCategory.toLowerCase();
      final allMuscles = [...ex.primaryMuscles, ...ex.secondaryMuscles]
          .map((m) => m.toLowerCase())
          .toList();
      final cat = ex.category.toLowerCase();

      if (query == "legs")
        return allMuscles.any((m) => [
              "quadriceps",
              "hamstrings",
              "calves",
              "glutes",
              "adductors",
              "abductors"
            ].contains(m));
      if (query == "arms")
        return allMuscles
            .any((m) => ["biceps", "triceps", "forearms"].contains(m));
      if (query == "core")
        return allMuscles.any((m) => ["abdominals"].contains(m));
      if (query == "back")
        return allMuscles
            .any((m) => ["lats", "middle back", "lower back"].contains(m));
      if (query == "chest") return allMuscles.any((m) => ["chest"].contains(m));
      if (query == "shoulders")
        return allMuscles.any((m) => ["shoulders", "traps"].contains(m));
      if (query == "cardio") return cat == "cardio" || cat == "plyometrics";
      return allMuscles.any((m) => m.contains(query));
    }).toList();

    return categoryFiltered.where((ex) {
      final matchesSearch = _fuzzyMatch(ex.name, _searchQuery);
      final safeEquipment = ex.equipment.toLowerCase();
      final matchesEquipment = _activeEquipment == 'All' ||
          (_activeEquipment == 'Body Weight' && safeEquipment == 'body only') ||
          safeEquipment.contains(_activeEquipment.toLowerCase());
      return matchesSearch && matchesEquipment;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsyncValue = ref.watch(exercisesProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close,
                          color: Colors.white, size: isSmallScreen ? 24 : 28),
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'ADD EXERCISE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 40 : 48),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24, vertical: 8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                      border: Border.all(color: AppColors.border)),
                  child: TextField(
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: isSmallScreen ? 13 : 14,
                    ),
                    cursorColor: AppColors.accent,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search,
                          color: AppColors.textSecondary,
                          size: isSmallScreen ? 16 : 18),
                      hintText: 'Search exercises...',
                      hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: isSmallScreen ? 12 : 14),
                      border: InputBorder.none,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.cancel,
                                  color: AppColors.textSecondary,
                                  size: isSmallScreen ? 14 : 16),
                              onPressed: () => setState(() => _searchQuery = ''))
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Category chips
              SizedBox(
                height: isSmallScreen ? 36 : 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
                  itemCount: _categoryFilters.length,
                  itemBuilder: (context, index) {
                    final filter = _categoryFilters[index];
                    final isActive = _activeCategory == filter;
                    final isFav = filter == 'Favorites';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isFav)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.star, size: 14,
                                    color: isActive ? Colors.black : Colors.amber),
                              ),
                            Text(filter,
                                style: TextStyle(
                                    color: isActive ? Colors.black : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 11 : 12)),
                          ],
                        ),
                        selected: isActive,
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                            color: isActive ? AppColors.accent : AppColors.border),
                        onSelected: (selected) =>
                            setState(() => _activeCategory = filter),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Equipment chips
              SizedBox(
                height: isSmallScreen ? 36 : 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
                  itemCount: _equipmentFilters.length,
                  itemBuilder: (context, index) {
                    final filter = _equipmentFilters[index];
                    final isActive = _activeEquipment == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter,
                            style: TextStyle(
                                color: isActive ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 11 : 12)),
                        selected: isActive,
                        selectedColor: Colors.white,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                            color: isActive ? Colors.white : AppColors.border),
                        onSelected: (selected) =>
                            setState(() => _activeEquipment = filter),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: exercisesAsyncValue.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.accent)),
                  error: (err, stack) => Center(
                      child: Text('Error: $err',
                          style: const TextStyle(color: Colors.red))),
                  data: (allExercises) {
                    final filteredList = _filterExercises(allExercises);
                    
                    if (filteredList.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _activeCategory == 'Favorites' ? Icons.star_border : Icons.fitness_center,
                              size: 48,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _activeCategory == 'Favorites'
                                  ? 'No favorite exercises yet.\nStar exercises to add them here!'
                                  : 'No exercises found.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 24, vertical: 8),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final ex = filteredList[index];
                        final isFav = ref.watch(favoritesProvider).exerciseIds.contains(ex.id);
                        
                        return GestureDetector(
                          onTap: () => context.push('/library/exercise/${ex.id}'),
                          child: Container(
                            margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                            decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                                border: Border.all(color: AppColors.border)),
                            child: Row(
                              children: [
                                _Thumbnail(images: ex.images),
                                SizedBox(width: isSmallScreen ? 12 : 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (isFav)
                                            const Padding(
                                              padding: EdgeInsets.only(right: 6),
                                              child: Icon(Icons.star,
                                                  color: Colors.amber, size: 16),
                                            ),
                                          Expanded(
                                            child: Text(ex.name,
                                                style: TextStyle(
                                                    color: AppColors.textPrimary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: isSmallScreen ? 14 : 16),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: isSmallScreen ? 3 : 4),
                                      Text(
                                          ex.primaryMuscles.join(', ').toUpperCase(),
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: isSmallScreen ? 9 : 10,
                                              letterSpacing: 1)),
                                    ],
                                  ),
                                ),
                                // Favorite button
                                IconButton(
                                  icon: Icon(
                                    isFav ? Icons.star : Icons.star_border,
                                    color: isFav ? Colors.amber : Colors.white38,
                                    size: isSmallScreen ? 20 : 24,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    ref.read(favoritesProvider.notifier).toggleFavorite(ex.id);
                                  },
                                ),
                                // Add button
                                IconButton(
                                  icon: Icon(Icons.add_circle,
                                      color: AppColors.accent,
                                      size: isSmallScreen ? 24 : 28),
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    ref
                                        .read(activeWorkoutProvider.notifier)
                                        .addExercise(ex.id);
                                    context.pop(ex.id);
                                  },
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatefulWidget {
  final List<String> images;
  const _Thumbnail({required this.images});
  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted)
          setState(
              () => _currentIndex = (_currentIndex + 1) % widget.images.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty)
      return Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
              color: Colors.white10, borderRadius: BorderRadius.circular(12)));
    final String path = 'assets/images/${widget.images[_currentIndex].replaceAll('/', '_')}';
    return Container(
      height: 60,
      width: 60,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          color: Colors.white10, borderRadius: BorderRadius.circular(12)),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: Image.asset(path,
            key: ValueKey(path),
            fit: BoxFit.cover,
            height: 60,
            width: 60,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.fitness_center, color: Colors.white24)),
      ),
    );
  }
} 