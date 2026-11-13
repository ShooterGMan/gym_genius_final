import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/active_workout_provider.dart';
import '../theme/app_theme.dart';

class MainLayout extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayout({super.key, required this.navigationShell});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  DateTime? _lastBackPress;

  void _onBranchSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  /// Back on a non-home tab returns to Dashboard; on Dashboard a second
  /// press within 2s exits (standard Android pattern).
  void _handleBack() {
    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0);
      return;
    }
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Press back again to exit'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final activeWorkout = ref.watch(activeWorkoutProvider);
    final notifier = ref.read(activeWorkoutProvider.notifier);

    // Get screen size for responsive layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 400;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: Stack(
          children: [
            widget.navigationShell,

            // Active Workout Banner
            if (activeWorkout.isActive)
              Positioned(
                left: isSmallScreen ? 8 : 16,
                right: isSmallScreen ? 8 : 16,
                bottom: isSmallScreen ? 80 : 100,
                child: GestureDetector(
                  onTap: () => context.push('/workout'),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: isSmallScreen ? 8 : 12),
                    decoration: BoxDecoration(
                      color: activeWorkout.isResting
                          ? AppColors.accent
                          : AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(isSmallScreen ? 16 : 20),
                      border: Border.all(
                        color: activeWorkout.isResting
                            ? AppColors.accent
                            : AppColors.accent.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: isSmallScreen ? 30 : 36,
                          width: isSmallScreen ? 30 : 36,
                          decoration: BoxDecoration(
                            color: activeWorkout.isResting
                                ? Colors.black12
                                : AppColors.accent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            activeWorkout.isResting
                                ? Icons.timer
                                : Icons.fitness_center,
                            color: activeWorkout.isResting
                                ? Colors.black
                                : AppColors.accent,
                            size: isSmallScreen ? 16 : 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                activeWorkout.isResting
                                    ? "RESTING"
                                    : "ACTIVE SESSION",
                                style: TextStyle(
                                  color: activeWorkout.isResting
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 10 : 12,
                                  letterSpacing: 1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                activeWorkout.isResting
                                    ? "Tap to return to workout"
                                    : "${activeWorkout.completedSetCount} sets done • tap to open",
                                style: TextStyle(
                                  color: activeWorkout.isResting
                                      ? Colors.black54
                                      : AppColors.textSecondary,
                                  fontSize: isSmallScreen ? 9 : 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          notifier.formatTime(
                            activeWorkout.isResting
                                ? activeWorkout.restSeconds
                                : activeWorkout.elapsedSeconds,
                          ),
                          style: TextStyle(
                            color: activeWorkout.isResting
                                ? Colors.black
                                : AppColors.accent,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
          ),
          child: BottomNavigationBar(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: _onBranchSelected,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.background,
            selectedItemColor: AppColors.accent,
            unselectedItemColor: AppColors.textSecondary,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedFontSize: isSmallScreen ? 8 : (isMediumScreen ? 9 : 10),
            unselectedFontSize: isSmallScreen ? 8 : (isMediumScreen ? 9 : 10),
            selectedLabelStyle: TextStyle(
              fontSize: isSmallScreen ? 8 : (isMediumScreen ? 9 : 10),
              fontWeight: FontWeight.bold,
              letterSpacing: isSmallScreen ? 0.5 : 1,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: isSmallScreen ? 8 : (isMediumScreen ? 9 : 10),
              fontWeight: FontWeight.bold,
              letterSpacing: isSmallScreen ? 0.5 : 1,
            ),
            iconSize: isSmallScreen ? 20 : (isMediumScreen ? 22 : 24),
            elevation: 0,
            landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
            items: [
              _buildNavItem(Icons.home_outlined, Icons.home, 'HOME', 'HOME',
                  isSmallScreen),
              _buildNavItem(Icons.fitness_center_outlined, Icons.fitness_center,
                  'LIBRARY', 'LIBRARY', isSmallScreen),
              _buildNavItem(Icons.list_alt_outlined, Icons.list_alt, 'PROGRAMS',
                  'PROGRAMS', isSmallScreen),
              _buildNavItem(Icons.insights_outlined, Icons.insights, 'PROGRESS',
                  'PROGRESS', isSmallScreen),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, IconData activeIcon,
      String shortLabel, String longLabel, bool isSmallScreen) {
    return BottomNavigationBarItem(
      icon: Icon(icon),
      activeIcon: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.2),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(activeIcon, color: AppColors.accent),
      ),
      label: isSmallScreen ? shortLabel : longLabel,
      tooltip: longLabel,
    );
  }
}
