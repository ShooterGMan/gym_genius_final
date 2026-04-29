import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../providers/program_provider.dart';
import '../providers/settings_provider.dart';
import '../services/image_cache_service.dart';
import '../models/program.dart';
import '../theme/app_theme.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _searchQuery = '';
  WorkoutCategory? _selectedCategory;
  List<String> _selectedEquipment = [];
  Difficulty? _selectedDifficulty;
  bool _showFilters = false;

  final List<WorkoutCategory> _categories = WorkoutCategory.values;
  final List<Difficulty> _difficulties = Difficulty.values;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(programProvider).popularPrograms.isEmpty) {
        ref.read(programProvider.notifier).reloadPopularPrograms();
      }
      _preloadWorkoutImages();
    });
  }

  Future<void> _preloadWorkoutImages() async {
    try {
      final programs = ref.read(programProvider).popularPrograms;
      final paths = programs.map((p) => p.coverImage).toList();
      for (final path in paths) {
        try {
          await rootBundle.load(path);
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final programState = ref.watch(programProvider);
    final settings = ref.watch(settingsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    List<Program> filteredPrograms = programState.popularPrograms;

    if (_searchQuery.isNotEmpty) {
      filteredPrograms = filteredPrograms
          .where((p) =>
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.description.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_selectedCategory != null) {
      filteredPrograms = filteredPrograms
          .where((p) => p.categories.contains(_selectedCategory))
          .toList();
    }

    if (_selectedDifficulty != null) {
      filteredPrograms = filteredPrograms
          .where((p) => p.difficulty == _selectedDifficulty)
          .toList();
    }

    if (_selectedEquipment.isNotEmpty) {
      filteredPrograms = filteredPrograms.where((p) {
        return _selectedEquipment.every((selectedEq) {
          return p.equipment.any((programEq) =>
              programEq.toLowerCase().contains(selectedEq.toLowerCase()) ||
              selectedEq.toLowerCase().contains(programEq.toLowerCase()));
        });
      }).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isSmallScreen),
            _buildSearchBar(isSmallScreen),
            _buildCategoryChips(isSmallScreen),
            if (_showFilters) _buildFilterPanel(settings, isSmallScreen),
            Expanded(
              child: programState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent))
                  : filteredPrograms.isEmpty
                      ? _buildEmptyState(isSmallScreen)
                      : _buildProgramGrid(filteredPrograms, isSmallScreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 16 : 24,
        isSmallScreen ? 12 : 16,
        isSmallScreen ? 16 : 24,
        8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "DISCOVER",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 22 : 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              Text(
                "Find your next program",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
            ],
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
    );
  }

  Widget _buildSearchBar(bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: isSmallScreen ? 12 : 16,
      ),
      child: Container(
        height: isSmallScreen ? 42 : 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
          border: Border.all(color: Colors.white10),
        ),
        child: TextField(
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 13 : 14,
          ),
          cursorColor: AppColors.accent,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search programs...',
            hintStyle: TextStyle(
              color: Colors.white38,
              fontSize: isSmallScreen ? 12 : 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white38,
              size: isSmallScreen ? 18 : 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.white38,
                      size: isSmallScreen ? 18 : 20,
                    ),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(bool isSmallScreen) {
    return SizedBox(
      height: isSmallScreen ? 42 : 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 24,
        ),
        children: [
          _buildCategoryChip(null, "All", isSmallScreen),
          ..._categories
              .map((cat) => _buildCategoryChip(cat, _getCategoryLabel(cat), isSmallScreen)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(WorkoutCategory? category, String label, bool isSmallScreen) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 11 : 13,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedCategory = selected ? category : null);
        },
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accent,
        checkmarkColor: Colors.black,
        side: BorderSide(
          color: isSelected ? AppColors.accent : Colors.white10,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 10 : 12,
          vertical: isSmallScreen ? 6 : 8,
        ),
      ),
    );
  }

  Widget _buildFilterPanel(SettingsState settings, bool isSmallScreen) {
    final availableEquipment = [
      'Bodyweight',
      'Dumbbells',
      'Barbell',
      'Machines',
      'Cables'
    ];

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14 : 20),
      margin: EdgeInsets.fromLTRB(
        isSmallScreen ? 16 : 24,
        8,
        isSmallScreen ? 16 : 24,
        isSmallScreen ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "DIFFICULTY",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: isSmallScreen ? 10 : 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          Wrap(
            spacing: 8,
            children: _difficulties.map((diff) {
              final isSelected = _selectedDifficulty == diff;
              return ChoiceChip(
                label: Text(
                  _getDifficultyLabel(diff),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedDifficulty = selected ? diff : null);
                },
                backgroundColor: AppColors.background,
                selectedColor: _getDifficultyColor(diff),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: isSmallScreen ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10 : 12,
                  vertical: isSmallScreen ? 6 : 8,
                ),
              );
            }).toList(),
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          Text(
            "EQUIPMENT",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: isSmallScreen ? 10 : 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableEquipment.map((eq) {
              final isSelected = _selectedEquipment.contains(eq);
              return FilterChip(
                label: Text(
                  eq,
                  style: TextStyle(fontSize: isSmallScreen ? 11 : 12),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedEquipment.add(eq);
                    } else {
                      _selectedEquipment.remove(eq);
                    }
                  });
                },
                backgroundColor: AppColors.background,
                selectedColor: AppColors.accent.withOpacity(0.2),
                checkmarkColor: AppColors.accent,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.accent : Colors.white70,
                  fontSize: isSmallScreen ? 11 : 12,
                  fontWeight: FontWeight.w500,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.accent : Colors.white10,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10 : 12,
                  vertical: isSmallScreen ? 6 : 8,
                ),
              );
            }).toList(),
          ),
          if (_selectedEquipment.isNotEmpty) ...[
            SizedBox(height: isSmallScreen ? 12 : 16),
            TextButton(
              onPressed: () => setState(() => _selectedEquipment.clear()),
              child: Text(
                "Clear Equipment Filters",
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: isSmallScreen ? 11 : 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgramGrid(List<Program> programs, bool isSmallScreen) {
    return GridView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: isSmallScreen ? 12 : 16,
        crossAxisSpacing: isSmallScreen ? 12 : 16,
        childAspectRatio: isSmallScreen ? 0.72 : 0.75,
      ),
      itemCount: programs.length,
      itemBuilder: (context, index) {
        final program = programs[index];
        return _buildProgramCard(program, isSmallScreen);
      },
    );
  }

  Widget _buildProgramCard(Program program, bool isSmallScreen) {
    String imagePath = program.coverImage;
    final borderRadius = isSmallScreen ? 16.0 : 20.0;

    return GestureDetector(
      onTap: () => context.push('/discover/program/${program.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.white10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            children: [
              // Program cover image with caching
              Positioned.fill(
                child: ImageCacheService.cachedImage(
                  imagePath,
                  fit: BoxFit.cover,
                  placeholder: ImageCacheService.shimmerPlaceholder(
                    borderRadius: borderRadius,
                  ),
                  errorWidget: Container(
                    color: AppColors.surface,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: isSmallScreen ? 32 : 40,
                          color: AppColors.accent.withOpacity(0.5),
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                          child: Text(
                            program.name,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: isSmallScreen ? 9 : 10,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                        Colors.black.withOpacity(0.8),
                      ],
                      stops: const [0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              // Program info
              Positioned(
                left: isSmallScreen ? 10 : 12,
                right: isSmallScreen ? 10 : 12,
                bottom: isSmallScreen ? 10 : 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Difficulty badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 6 : 8,
                        vertical: isSmallScreen ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: program.difficultyColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                      ),
                      child: Text(
                        program.difficultyLabel,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 8 : 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 5 : 8),
                    // Program name
                    Text(
                      program.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 3 : 4),
                    // Duration
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: isSmallScreen ? 9 : 10,
                          color: Colors.white70,
                        ),
                        SizedBox(width: isSmallScreen ? 3 : 4),
                        Text(
                          "${program.totalWorkouts} days",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isSmallScreen ? 9 : 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isSmallScreen) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isSmallScreen ? 80 : 100,
            height: isSmallScreen ? 80 : 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(
              Icons.fitness_center,
              size: isSmallScreen ? 36 : 48,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          SizedBox(height: isSmallScreen ? 20 : 24),
          Text(
            "No programs found",
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            "Try adjusting your filters",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: isSmallScreen ? 12 : 14,
            ),
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _selectedCategory = null;
                _selectedDifficulty = null;
                _selectedEquipment.clear();
                _showFilters = false;
              });
            },
            child: Text(
              "Clear all filters",
              style: TextStyle(
                color: AppColors.accent,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel(WorkoutCategory category) {
    switch (category) {
      case WorkoutCategory.strength:
        return "Strength";
      case WorkoutCategory.hypertrophy:
        return "Hypertrophy";
      case WorkoutCategory.endurance:
        return "Endurance";
      case WorkoutCategory.weightLoss:
        return "Weight Loss";
      case WorkoutCategory.fullBody:
        return "Full Body";
      case WorkoutCategory.upperLower:
        return "Upper/Lower";
      case WorkoutCategory.ppl:
        return "PPL";
      case WorkoutCategory.broSplit:
        return "Bro Split";
    }
  }

  String _getDifficultyLabel(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return "Beginner";
      case Difficulty.intermediate:
        return "Intermediate";
      case Difficulty.advanced:
        return "Advanced";
    }
  }

  Color _getDifficultyColor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return const Color(0xFF4CAF50);
      case Difficulty.intermediate:
        return const Color(0xFFFF9800);
      case Difficulty.advanced:
        return const Color(0xFFF44336);
    }
  }
}