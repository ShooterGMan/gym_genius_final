import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/exercise_provider.dart';
import '../providers/favorites_provider.dart';
import '../models/exercise.dart';
import '../theme/app_theme.dart';
import '../widgets/routine_selector_bottom_sheet.dart';

class ExerciseListScreen extends ConsumerStatefulWidget {
  final String category;
  const ExerciseListScreen({super.key, required this.category});

  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  late String _searchQuery;
  String _activeFilter = 'All';
  String _activeEquipment = 'All';
  String _activeDifficulty = 'All';
  bool _showFilters = false;
  bool _showFavoritesOnly = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _muscleFilters = [
    'All',
    'Favorites',
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Arms',
    'Core',
    'Cardio',
  ];

  final List<String> _equipmentFilters = [
    'All',
    'Body Only',
    'Dumbbell',
    'Barbell',
    'Cable',
    'Machine',
    'Kettlebells',
    'Bands',
  ];

  final List<String> _difficultyFilters = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  void initState() {
    super.initState();
    _searchQuery = '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = GoRouterState.of(context);
    final searchParam = state.uri.queryParameters['search'];
    if (searchParam != null && searchParam.isNotEmpty) {
      _searchQuery = searchParam;
      _searchController.text = searchParam;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Exercise> _filterExercises(List<Exercise> allExercises) {
    final favorites = ref.watch(favoritesProvider).exerciseIds;

    List<Exercise> filtered = allExercises.where((ex) {
      // Category filter
      if (widget.category != 'all' && widget.category != 'favorites') {
        final query = widget.category.toLowerCase();
        final allMuscles = [...ex.primaryMuscles, ...ex.secondaryMuscles]
            .map((m) => m.toLowerCase())
            .toList();
        final cat = ex.category.toLowerCase();

        if (query == "legs") {
          if (!allMuscles.any((m) => [
                "quadriceps", "hamstrings", "calves", "glutes",
                "adductors", "abductors"
              ].contains(m))) return false;
        } else if (query == "arms") {
          if (!allMuscles.any((m) => ["biceps", "triceps", "forearms"].contains(m)))
            return false;
        } else if (query == "core") {
          if (!allMuscles.any((m) => ["abdominals"].contains(m))) return false;
        } else if (query == "back") {
          if (!allMuscles.any((m) => ["lats", "middle back", "lower back"].contains(m)))
            return false;
        } else if (query == "chest") {
          if (!allMuscles.any((m) => ["chest"].contains(m))) return false;
        } else if (query == "shoulders") {
          if (!allMuscles.any((m) => ["shoulders", "traps"].contains(m)))
            return false;
        } else if (query == "cardio") {
          if (cat != "cardio" && cat != "plyometrics") return false;
        }
      }

      // Favorites filter
      if (widget.category == 'favorites') {
        if (!favorites.contains(ex.id)) return false;
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        if (!ex.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // Active muscle filter (including Favorites)
      if (_activeFilter == 'Favorites') {
        if (!favorites.contains(ex.id)) return false;
      } else if (_activeFilter != 'All') {
        final targetMuscle = _activeFilter.toLowerCase();
        final allMuscles = [...ex.primaryMuscles, ...ex.secondaryMuscles]
            .map((m) => m.toLowerCase())
            .toList();

        if (targetMuscle == 'chest' && !allMuscles.contains('chest')) return false;
        if (targetMuscle == 'back' &&
            !allMuscles.any((m) => ['lats', 'middle back', 'lower back'].contains(m)))
          return false;
        if (targetMuscle == 'legs' &&
            !allMuscles.any((m) =>
                ['quadriceps', 'hamstrings', 'calves', 'glutes'].contains(m)))
          return false;
        if (targetMuscle == 'shoulders' && !allMuscles.contains('shoulders'))
          return false;
        if (targetMuscle == 'arms' &&
            !allMuscles.any((m) => ['biceps', 'triceps', 'forearms'].contains(m)))
          return false;
        if (targetMuscle == 'core' && !allMuscles.contains('abdominals'))
          return false;
        if (targetMuscle == 'cardio' &&
            ex.category != 'cardio' && ex.category != 'plyometrics') return false;
      }

      // Equipment filter
      if (_activeEquipment != 'All') {
        final eq = _activeEquipment.toLowerCase();
        if (eq == 'body only' && ex.equipment != 'body only') return false;
        if (eq != 'body only' && !ex.equipment.toLowerCase().contains(eq))
          return false;
      }

      // Difficulty filter
      if (_activeDifficulty != 'All') {
        if (ex.level.toLowerCase() != _activeDifficulty.toLowerCase())
          return false;
      }

      // Favorites toggle
      if (_showFavoritesOnly) {
        if (!favorites.contains(ex.id)) return false;
      }

      return true;
    }).toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsyncValue = ref.watch(exercisesProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
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
                    icon: Icon(Icons.chevron_left,
                        color: Colors.white, size: isSmallScreen ? 26 : 30),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.category == 'all'
                          ? 'ALL EXERCISES'
                          : widget.category == 'favorites'
                              ? 'FAVORITES'
                              : widget.category.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  // Favorites toggle button
                  IconButton(
                    icon: Icon(
                      _showFavoritesOnly ? Icons.star : Icons.star_border,
                      color: _showFavoritesOnly ? AppColors.accent : Colors.white70,
                      size: isSmallScreen ? 22 : 24,
                    ),
                    onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
                    tooltip: 'Show favorites only',
                  ),
                  IconButton(
                    icon: Icon(
                      _showFilters ? Icons.filter_list_off : Icons.filter_list,
                      color: _showFilters ? AppColors.accent : Colors.white70,
                      size: isSmallScreen ? 22 : 24,
                    ),
                    onPressed: () => setState(() => _showFilters = !_showFilters),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 24, vertical: 8),
              child: Container(
                height: isSmallScreen ? 42 : 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: isSmallScreen ? 13 : 14,
                  ),
                  cursorColor: AppColors.accent,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search exercises...',
                    hintStyle: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                    prefixIcon: Icon(Icons.search,
                        color: AppColors.textSecondary,
                        size: isSmallScreen ? 18 : 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.cancel,
                                color: AppColors.textSecondary,
                                size: isSmallScreen ? 16 : 18),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                  ),
                ),
              ),
            ),

            // Filter Panel
            if (_showFilters)
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                margin: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "MUSCLE GROUP",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: isSmallScreen ? 9 : 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _muscleFilters.map((filter) {
                        final isActive = _activeFilter == filter;
                        final isFavorite = filter == 'Favorites';
                        return FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isFavorite)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(Icons.star, size: 14,
                                      color: isActive ? Colors.black : Colors.amber),
                                ),
                              Text(filter, style: TextStyle(fontSize: isSmallScreen ? 11 : 12)),
                            ],
                          ),
                          selected: isActive,
                          onSelected: (selected) {
                            setState(() => _activeFilter = selected ? filter : 'All');
                          },
                          backgroundColor: AppColors.background,
                          selectedColor: AppColors.accent.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.accent,
                          labelStyle: TextStyle(
                            color: isActive ? AppColors.accent : Colors.white70,
                            fontSize: isSmallScreen ? 11 : 12,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "EQUIPMENT",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: isSmallScreen ? 9 : 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _equipmentFilters.map((filter) {
                        final isActive = _activeEquipment == filter;
                        return FilterChip(
                          label: Text(filter, style: TextStyle(fontSize: isSmallScreen ? 11 : 12)),
                          selected: isActive,
                          onSelected: (selected) {
                            setState(() => _activeEquipment = selected ? filter : 'All');
                          },
                          backgroundColor: AppColors.background,
                          selectedColor: AppColors.accent.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.accent,
                          labelStyle: TextStyle(
                            color: isActive ? AppColors.accent : Colors.white70,
                            fontSize: isSmallScreen ? 11 : 12,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "DIFFICULTY",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: isSmallScreen ? 9 : 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _difficultyFilters.map((filter) {
                        final isActive = _activeDifficulty == filter;
                        return FilterChip(
                          label: Text(filter, style: TextStyle(fontSize: isSmallScreen ? 11 : 12)),
                          selected: isActive,
                          onSelected: (selected) {
                            setState(() => _activeDifficulty = selected ? filter : 'All');
                          },
                          backgroundColor: AppColors.background,
                          selectedColor: _getDifficultyColor(filter).withValues(alpha: 0.2),
                          checkmarkColor: _getDifficultyColor(filter),
                          labelStyle: TextStyle(
                            color: isActive ? _getDifficultyColor(filter) : Colors.white70,
                            fontSize: isSmallScreen ? 11 : 12,
                          ),
                        );
                      }).toList(),
                    ),
                    if (_activeFilter != 'All' || _activeEquipment != 'All' || _activeDifficulty != 'All')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _activeFilter = 'All';
                              _activeEquipment = 'All';
                              _activeDifficulty = 'All';
                            });
                          },
                          child: Text("Clear All Filters",
                              style: TextStyle(fontSize: isSmallScreen ? 11 : 12)),
                        ),
                      ),
                  ],
                ),
              ),

            // Results count
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "EXERCISES",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            // Exercise List
            Expanded(
              child: exercisesAsyncValue.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (err, stack) => Center(
                  child: Text('Error: $err',
                      style: const TextStyle(color: Colors.red)),
                ),
                data: (allExercises) {
                  final filteredList = _filterExercises(allExercises);

                  if (filteredList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showFavoritesOnly ? Icons.star_border : Icons.fitness_center,
                            size: isSmallScreen ? 40 : 48,
                            color: Colors.white24,
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          Text(
                            _showFavoritesOnly
                                ? 'No favorite exercises yet'
                                : 'No exercises found',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Text(
                            _showFavoritesOnly
                                ? 'Tap the star icon on exercises to add them here'
                                : 'Try adjusting your filters',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: isSmallScreen ? 11 : 13,
                            ),
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
                      final levelColor = ex.level == 'beginner'
                          ? Colors.greenAccent
                          : (ex.level == 'intermediate'
                              ? Colors.amberAccent
                              : Colors.redAccent);

                      return GestureDetector(
                        onTap: () => context.push('/library/exercise/${ex.id}'),
                        child: Container(
                          margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                          padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              AnimatedExerciseThumbnail(images: ex.images),
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
                                          child: Text(
                                            ex.name,
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: isSmallScreen ? 14 : 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isSmallScreen ? 3 : 4),
                                    Row(
                                      children: [
                                        Text(
                                          ex.equipment == 'body only'
                                              ? 'Body Weight'
                                              : ex.equipment,
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: isSmallScreen ? 10 : 12,
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 6),
                                          child: Text('•',
                                              style: TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: isSmallScreen ? 10 : 12)),
                                        ),
                                        Text(
                                          ex.level.toUpperCase(),
                                          style: TextStyle(
                                            color: levelColor,
                                            fontSize: isSmallScreen ? 9 : 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isSmallScreen ? 3 : 4),
                                    Text(
                                      ex.primaryMuscles.take(2).join(', '),
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: isSmallScreen ? 9 : 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Favorite button
                              IconButton(
                                icon: Icon(
                                  isFav ? Icons.star : Icons.star_border,
                                  color: isFav ? Colors.amber : Colors.white38,
                                  size: isSmallScreen ? 22 : 26,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  ref.read(favoritesProvider.notifier).toggleFavorite(ex.id);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.add_circle,
                                    color: AppColors.accent,
                                    size: isSmallScreen ? 24 : 28),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => RoutineSelectorBottomSheet(
                                      exerciseId: ex.id,
                                      exerciseName: ex.name,
                                    ),
                                  );
                                },
                              ),
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
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF4CAF50);
      case 'intermediate':
        return const Color(0xFFFF9800);
      case 'advanced':
        return const Color(0xFFF44336);
      default:
        return Colors.white70;
    }
  }
}

class AnimatedExerciseThumbnail extends StatefulWidget {
  final List<String> images;
  const AnimatedExerciseThumbnail({super.key, required this.images});

  @override
  State<AnimatedExerciseThumbnail> createState() =>
      _AnimatedExerciseThumbnailState();
}

class _AnimatedExerciseThumbnailState extends State<AnimatedExerciseThumbnail> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % widget.images.length;
          });
        }
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
    if (widget.images.isEmpty) {
      return Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    final String currentImagePath =
        'assets/images/${widget.images[_currentIndex].replaceAll('/', '_')}';

    return Container(
      height: 60,
      width: 60,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: Image.asset(
          currentImagePath,
          key: ValueKey<String>(currentImagePath),
          fit: BoxFit.cover,
          height: 60,
          width: 60,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.white10,
            child: const Icon(Icons.fitness_center,
                color: Colors.white24, size: 24),
          ),
        ),
      ),
    );
  }
}