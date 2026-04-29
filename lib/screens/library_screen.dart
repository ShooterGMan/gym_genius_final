import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/image_cache_service.dart';
import '../theme/app_theme.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  static const List<Map<String, String>> categories = [
    {'name': 'CHEST', 'image': 'assets/workout_covers/categories/chest.jpg'},
    {'name': 'BACK', 'image': 'assets/workout_covers/categories/back.jpg'},
    {'name': 'LEGS', 'image': 'assets/workout_covers/categories/legs.jpg'},
    {'name': 'FAVORITES', 'image': 'assets/workout_covers/categories/full_body.jpg'},
    {
      'name': 'SHOULDERS',
      'image': 'assets/workout_covers/categories/shoulders.jpg'
    },
    {'name': 'ARMS', 'image': 'assets/workout_covers/categories/arms.jpg'},
    {'name': 'CORE', 'image': 'assets/workout_covers/categories/core.jpg'},
    {'name': 'CARDIO', 'image': 'assets/workout_covers/categories/cardio.jpg'},
    {
      'name': 'FULL BODY',
      'image': 'assets/workout_covers/categories/full_body.jpg'
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadCategoryImages();
    });
  }

  Future<void> _preloadCategoryImages() async {
    try {
      final paths = categories.map((c) => c['image']!).toList();
      for (final path in paths) {
        try {
          await rootBundle.load(path);
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final padding = AppTheme.responsivePadding(context);
    final headerFontSize = AppTheme.responsiveFontSize(context, 28);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: padding,
              sliver: SliverToBoxAdapter(
                child: _isSearching
                    ? _buildSearchBar(isSmallScreen)
                    : _buildHeader(headerFontSize, isSmallScreen),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 24,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: isSmallScreen ? 12 : 16,
                  crossAxisSpacing: isSmallScreen ? 12 : 16,
                  childAspectRatio: isSmallScreen ? 0.8 : 0.85,
                ),
                delegate: SliverChildListDelegate(
                  categories
                      .map((cat) => _buildCategoryCard(
                            context,
                            cat['name']!,
                            cat['image']!,
                            isSmallScreen,
                          ))
                      .toList(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double headerFontSize, bool isSmallScreen) {
    final iconSize = isSmallScreen ? 24.0 : 28.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "LIBRARY",
          style: TextStyle(
            color: Colors.white,
            fontSize: headerFontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        IconButton(
          icon: Icon(Icons.search, color: AppColors.accent, size: iconSize),
          onPressed: () {
            // Navigate to all exercises search
            context.push('/library/all');
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isSmallScreen) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: isSmallScreen ? 42 : 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 13 : 14,
              ),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                hintText: 'Search all exercises...',
                hintStyle: TextStyle(
                  color: Colors.white38,
                  fontSize: isSmallScreen ? 12 : 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white38,
                  size: isSmallScreen ? 18 : 20,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  context.push('/library/all?search=$value');
                }
              },
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close,
            color: Colors.white70,
            size: isSmallScreen ? 22 : 24,
          ),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
      BuildContext context, String title, String assetPath, bool isSmallScreen) {
    final borderRadius = isSmallScreen ? 20.0 : 24.0;
    final fontSize = isSmallScreen ? 16.0 : 18.0;
    final iconSize = isSmallScreen ? 36.0 : 48.0;

    // Convert title to lowercase for the route
    final category = title.toLowerCase();
    // Handle special cases
    final routeCategory = title == 'FAVORITES' ? 'favorites' : 
    (title.toLowerCase() == 'full body' ? 'full_body' : title.toLowerCase());

    return GestureDetector(
      onTap: () {
        // Navigate to category exercises
        context.push('/library/$routeCategory');
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cached image with gapless playback to prevent flickering
              ImageCacheService.cachedImage(
                assetPath,
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
                        _getIconForCategory(title),
                        size: iconSize,
                        color: AppColors.accent.withOpacity(0.5),
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: fontSize * 0.7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Dark overlay for readability
              Container(
                color: Colors.black.withOpacity(0.5),
              ),
              // Category name label
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: fontSize,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 3 : 4),
                    Text(
                      "VIEW EXERCISES",
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 7 : 9,
                        letterSpacing: 1,
                      ),
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

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'CHEST':
        return Icons.fitness_center;
      case 'BACK':
        return Icons.accessibility_new;
      case 'LEGS':
        return Icons.directions_walk;
      case 'SHOULDERS':
        return Icons.arrow_upward;
      case 'ARMS':
        return Icons.pan_tool;
      case 'CORE':
        return Icons.circle;
      case 'CARDIO':
        return Icons.directions_run;
      default:
        return Icons.fitness_center;
    }
  }
}