import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/program_provider.dart';
import '../providers/active_workout_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/pr_tracker_provider.dart';
import '../models/program.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programState = ref.watch(programProvider);
    final trackerState = ref.watch(trackerProvider);
    final settingsState = ref.watch(settingsProvider);
    final prState = ref.watch(prTrackerProvider);
    final history = trackerState.history;
    final activeProgram = programState.activeProgram;
    final profile = settingsState.profile;

    final screenWidth = MediaQuery.of(context).size.width;
    final padding = AppTheme.responsivePadding(context);
    final headerFontSize = AppTheme.responsiveFontSize(context, 24);
    final subFontSize = AppTheme.responsiveFontSize(context, 10);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: padding,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting().toUpperCase(),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: subFontSize,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        profile.name.isNotEmpty ? profile.name.toUpperCase() : "ATHLETE",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: headerFontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSettingsButton(context),
              ],
            ),
            SizedBox(height: screenWidth < 360 ? 16 : 24),
            _buildFireCalendar(history, screenWidth),
            SizedBox(height: screenWidth < 360 ? 20 : 32),
            Text(
              "UP NEXT",
              style: TextStyle(
                color: Colors.white,
                fontSize: AppTheme.responsiveFontSize(context, 12),
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: screenWidth < 360 ? 12 : 16),
            if (activeProgram != null)
              _buildHeroCard(context, ref, activeProgram, programState, screenWidth)
            else
              _buildEmptyHeroCard(context, screenWidth),
            SizedBox(height: screenWidth < 360 ? 16 : 24),
            _buildBentoGrid(context, ref, screenWidth),
            SizedBox(height: screenWidth < 360 ? 16 : 24),
            _buildQuickStartButton(ref, context, screenWidth),
            SizedBox(height: screenWidth < 360 ? 80 : 100),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 18) return "Good Afternoon";
    return "Good Evening";
  }

  Widget _buildSettingsButton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonSize = screenWidth < 360 ? 36.0 : 40.0;
    final iconSize = screenWidth < 360 ? 16.0 : 18.0;

    return GestureDetector(
      onTap: () => context.push('/settings'),
      child: Container(
        height: buttonSize,
        width: buttonSize,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(Icons.person, color: AppColors.accent, size: iconSize),
      ),
    );
  }

  Widget _buildFireCalendar(List<CompletedWorkout> history, double screenWidth) {
    final now = DateTime.now();
    final daysSinceSunday = now.weekday % 7;
    final sunday = now.subtract(Duration(days: daysSinceSunday));

    final isSmallScreen = screenWidth < 360;
    final containerPadding = isSmallScreen ? 12.0 : 16.0;
    final itemWidth = isSmallScreen ? 36.0 : 42.0;
    final iconSize = isSmallScreen ? 16.0 : 20.0;
    final fontSize = isSmallScreen ? 10.0 : 12.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          final date = sunday.add(Duration(days: i));
          final isCompleted = history.any(
            (w) =>
                w.date.day == date.day &&
                w.date.month == date.month &&
                w.date.year == date.year,
          );
          final isToday = date.day == now.day &&
              date.month == now.month &&
              date.year == now.year;

          return SizedBox(
            width: itemWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ['S', 'M', 'T', 'W', 'T', 'F', 'S'][i],
                  style: TextStyle(
                    fontSize: isSmallScreen ? 9 : 10,
                    fontWeight: FontWeight.bold,
                    color: isToday ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Container(
                  height: isSmallScreen ? 30 : 36,
                  width: isSmallScreen ? 30 : 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.accent.withOpacity(0.1)
                        : isCompleted
                            ? AppColors.accent.withOpacity(0.05)
                            : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday
                        ? Border.all(color: AppColors.accent.withOpacity(0.3))
                        : isCompleted
                            ? Border.all(color: AppColors.accent.withOpacity(0.15))
                            : null,
                  ),
                  child: isCompleted
                      ? Icon(
                          Icons.local_fire_department,
                          color: AppColors.accent,
                          size: iconSize,
                        )
                      : Text(
                          "${date.day}",
                          style: TextStyle(
                            color: isToday ? Colors.white : Colors.white38,
                            fontWeight: isToday ? FontWeight.w900 : FontWeight.w500,
                            fontSize: fontSize,
                          ),
                        ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    WidgetRef ref,
    Program program,
    ProgramState programState,
    double screenWidth,
  ) {
    final nextRoutine = program
        .routines[programState.currentRoutineIndex % program.routines.length];

    final isSmallScreen = screenWidth < 360;
    final cardHeight = isSmallScreen ? 160.0 : 200.0;
    final titleSize = isSmallScreen ? 20.0 : 24.0;
    final subtitleSize = isSmallScreen ? 12.0 : 14.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        final activeNotifier = ref.read(activeWorkoutProvider.notifier);
        final programNotifier = ref.read(programProvider.notifier);

        activeNotifier.startEmptyWorkout();
        for (var planned in nextRoutine.exercises) {
          activeNotifier.addExercise(
            planned.exerciseId,
            setsCount: planned.sets,
            repsHint: planned.reps,
          );
        }
        programNotifier.nextRoutine();
        context.push('/workout');
      },
      child: Container(
        height: cardHeight,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isSmallScreen ? 24 : 32),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          children: [
            Image.asset(
              program.displayImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.surface,
                child: Icon(
                  Icons.fitness_center,
                  size: isSmallScreen ? 36 : 48,
                  color: Colors.white24,
                ),
              ),
            ),
            Container(color: Colors.black.withOpacity(0.6)),
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.black,
                          size: isSmallScreen ? 18 : 24,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 8 : 12,
                          vertical: isSmallScreen ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accent.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          "ACTIVE PLAN",
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: isSmallScreen ? 7 : 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    program.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Next: ${nextRoutine.name}",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: subtitleSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHeroCard(BuildContext context, double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    final cardHeight = isSmallScreen ? 160.0 : 200.0;
    final iconSize = isSmallScreen ? 36.0 : 48.0;
    final titleSize = isSmallScreen ? 16.0 : 18.0;
    final messageSize = isSmallScreen ? 10.0 : 12.0;

    return Container(
      height: cardHeight,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSmallScreen ? 24 : 32),
        border: Border.all(color: Colors.white10),
        color: AppColors.surface,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: iconSize,
              color: Colors.white.withOpacity(0.3),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              "No Active Program",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              "Discover or create a program to get started",
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: messageSize,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoGrid(BuildContext context, WidgetRef ref, double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    final prState = ref.watch(prTrackerProvider);
    final prCount = prState.heaviestWeight.length;

    return Column(
      children: [
        // Favorites
        _buildLongPortal(
          context,
          "FAVORITE EXERCISES",
          "Quick access to your starred exercises",
          Icons.star,
          "assets/placeholders/chest.avif",
          screenWidth,
          onTap: () => context.push('/library/favorites'),
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),

        // Personal Records
        _buildLongPortal(
          context,
          "PERSONAL RECORDS",
          prCount > 0 ? "$prCount exercises with PRs" : "Track your best lifts",
          Icons.emoji_events,
          "assets/placeholders/back.avif",
          screenWidth,
          onTap: () => context.push('/tracker'),
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),

        // My Programs
        _buildLongPortal(
          context,
          "MY PROGRAMS",
          "View your saved templates",
          Icons.folder_open,
          "assets/placeholders/full body.avif",
          screenWidth,
          onTap: () => context.push('/programs'),
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),

        // Discover
        _buildLongPortal(
          context,
          "DISCOVER",
          "Find new workout plans",
          Icons.explore,
          "assets/placeholders/cardio.avif",
          screenWidth,
          onTap: () => context.push('/discover'),
        ),
      ],
    );
  }

  Widget _buildLongPortal(
    BuildContext context,
    String title,
    String sub,
    IconData icon,
    String img,
    double screenWidth, {
    VoidCallback? onTap,
  }) {
    final isSmallScreen = screenWidth < 360;
    final height = isSmallScreen ? 80.0 : 100.0;
    final iconSize = isSmallScreen ? 16.0 : 20.0;
    final titleSize = isSmallScreen ? 14.0 : 16.0;
    final subSize = isSmallScreen ? 9.0 : 10.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          children: [
            Image.asset(
              img,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.surface,
              ),
            ),
            Container(color: Colors.black.withOpacity(0.7)),
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 14 : 20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Icon(icon, color: AppColors.accent, size: iconSize),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: titleSize,
                          ),
                        ),
                        Text(
                          sub,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: subSize,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartButton(WidgetRef ref, BuildContext context, double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    final verticalPadding = isSmallScreen ? 16.0 : 20.0;
    final fontSize = isSmallScreen ? 11.0 : 13.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          side: BorderSide(color: AppColors.accent.withOpacity(0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
          ),
          backgroundColor: AppColors.accent.withOpacity(0.05),
        ),
        onPressed: () {
          HapticFeedback.heavyImpact();
          ref.read(activeWorkoutProvider.notifier).startEmptyWorkout();
          context.push('/workout');
        },
        icon: Icon(Icons.flash_on, color: AppColors.accent, size: isSmallScreen ? 16 : 20),
        label: Text(
          "EMPTY QUICK START",
          style: TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}