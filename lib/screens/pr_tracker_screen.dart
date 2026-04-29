import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/pr_tracker_provider.dart';
import '../providers/exercise_provider.dart';
import '../models/exercise.dart';
import '../theme/app_theme.dart';

class PRTrackerScreen extends ConsumerWidget {
  const PRTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prState = ref.watch(prTrackerProvider);
    final exercises = ref.watch(exercisesProvider).value ?? [];
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                          _buildPRList(prState.heaviestWeight, exercises, 'weight', isSmallScreen),
                          _buildPRList(prState.mostReps, exercises, 'reps', isSmallScreen),
                          _buildPRList(prState.highestVolume, exercises, 'volume', isSmallScreen),
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
                color: Colors.white.withOpacity(0.5),
                fontSize: isSmallScreen ? 15 : 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 10),
            Text(
              "Complete workouts to start\ntracking your records!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
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

        return _buildPRCard(pr, exercise, index + 1, category, isSmallScreen);
      },
    );
  }

  Widget _buildPRCard(
    PersonalRecord pr,
    Exercise exercise,
    int rank,
    String category,
    bool isSmallScreen,
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
      displayUnit = 'kg';
    } else if (category == 'reps') {
      displayValue = '${pr.reps}';
      displayUnit = 'reps';
    } else {
      displayValue = '${pr.volume.toStringAsFixed(0)}';
      displayUnit = 'kg total';
    }

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 14),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        border: Border.all(
          color: rankColor?.withOpacity(0.3) ?? Colors.white.withOpacity(0.05),
        ),
        boxShadow: rankColor != null
            ? [
                BoxShadow(
                  color: rankColor.withOpacity(0.1),
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
              color: (rankColor ?? AppColors.accent).withOpacity(0.1),
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 14),
              border: Border.all(
                color: (rankColor ?? AppColors.accent).withOpacity(0.3),
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
                    color: (rankColor ?? AppColors.accent).withOpacity(0.7),
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