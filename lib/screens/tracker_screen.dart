import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/tracker_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/settings_provider.dart';
import '../models/exercise.dart';
import '../screens/pr_tracker_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/data_actions.dart';
import '../widgets/progress_photos_tab.dart';

class TrackerScreen extends ConsumerStatefulWidget {
  const TrackerScreen({super.key});
  @override
  ConsumerState<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends ConsumerState<TrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Only the "Progress" tab's FAB (add body metric) makes sense per tab.
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const List<String> _allMuscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Forearms',
    'Abs',
    'Quads',
    'Hamstrings',
    'Glutes',
    'Calves',
    'Traps',
    'Lats',
  ];

  static const Map<String, String> _muscleNameMap = {
    'abdominals': 'Abs',
    'abductors': 'Glutes',
    'adductors': 'Glutes',
    'biceps': 'Biceps',
    'calves': 'Calves',
    'chest': 'Chest',
    'forearms': 'Forearms',
    'glutes': 'Glutes',
    'hamstrings': 'Hamstrings',
    'lats': 'Lats',
    'lower back': 'Back',
    'middle back': 'Back',
    'neck': 'Traps',
    'quadriceps': 'Quads',
    'shoulders': 'Shoulders',
    'traps': 'Traps',
    'triceps': 'Triceps',
  };

  Map<String, int> _calculateBodyPartFrequency(
      List<CompletedWorkout> history, List<Exercise> exercises) {
    final Map<String, int> bodyPartCount = {};
    for (final muscle in _allMuscleGroups) {
      bodyPartCount[muscle] = 0;
    }

    for (final workout in history) {
      for (final liveEx in workout.routine) {
        final ex = exercises.firstWhere(
          (e) => e.id == liveEx.exerciseId,
          orElse: () => Exercise(
            id: '',
            name: '',
            equipment: '',
            level: '',
            primaryMuscles: [],
            secondaryMuscles: [],
            category: '',
            images: [],
            instructions: [],
          ),
        );

        for (final muscle in ex.primaryMuscles) {
          final displayName = _muscleNameMap[muscle.toLowerCase()];
          if (displayName != null && bodyPartCount.containsKey(displayName)) {
            bodyPartCount[displayName] = (bodyPartCount[displayName] ?? 0) + 1;
          }
        }
      }
    }

    return bodyPartCount;
  }

  @override
  Widget build(BuildContext context) {
    final tracker = ref.watch(trackerProvider);
    final exercises = ref.watch(exercisesProvider).value ?? [];
    final bodyParts = _calculateBodyPartFrequency(tracker.history, exercises);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    final thisMonthWorkouts = tracker.history
        .where((w) =>
            w.date.month == DateTime.now().month &&
            w.date.year == DateTime.now().year)
        .length;

    final lastWorkout = tracker.history.isNotEmpty
        ? '${tracker.history.first.date.day}/${tracker.history.first.date.month}'
        : '--';

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PROGRESS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 22 : 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Builder(
                      builder: (btnContext) => IconButton(
                        tooltip: 'Export to Excel',
                        icon: Icon(Icons.table_chart_outlined,
                            color: AppColors.accent,
                            size: isSmallScreen ? 22 : 24),
                        onPressed: () =>
                            DataActions.exportExcel(btnContext, ref),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Stats',
                      icon: Icon(Icons.bar_chart,
                          color: AppColors.accent,
                          size: isSmallScreen ? 22 : 24),
                      onPressed: () => _showStatsBottomSheet(context, tracker),
                    ),
                  ]),
                ],
              ),
            ),

            // Quick Stats Row
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 24,
                vertical: isSmallScreen ? 10 : 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      '$thisMonthWorkouts',
                      'This Month',
                      Icons.calendar_month,
                      isSmallScreen,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Expanded(
                    child: _buildStatCard(
                      lastWorkout,
                      'Last Workout',
                      Icons.timer,
                      isSmallScreen,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Expanded(
                    child: _buildStatCard(
                      '${tracker.history.length}',
                      'Total',
                      Icons.fitness_center,
                      isSmallScreen,
                    ),
                  ),
                ],
              ),
            ),

            // Tab Navigation
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: Colors.white24,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: isSmallScreen ? 10 : 12,
                letterSpacing: 2,
              ),
              isScrollable: isSmallScreen,
              tabAlignment: isSmallScreen ? TabAlignment.start : null,
              tabs: const [
                Tab(text: "ACTIVITY"),
                Tab(text: "BODY"),
                Tab(text: "RECORDS"),
                Tab(text: "PHOTOS"),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActivityTab(tracker.history, isSmallScreen),
                  _buildProgressTab(tracker, bodyParts, isSmallScreen),
                  const PRTrackerScreen(),
                  const ProgressPhotosTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index != 1
          ? null
          : FloatingActionButton(
        tooltip: 'Log body weight',
        onPressed: () => _showAddMetricDialog(),
        backgroundColor: AppColors.accent,
        child: Icon(Icons.add, color: Colors.black, size: isSmallScreen ? 20 : 24),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: isSmallScreen ? 18 : 20),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: isSmallScreen ? 3 : 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: isSmallScreen ? 8 : 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab(List<CompletedWorkout> history, bool isSmallScreen) {
    return ListView(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("THIS WEEK",
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: isSmallScreen ? 9 : 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            TextButton.icon(
              onPressed: () => _showFullCalendarSheet(context, history),
              icon: Icon(Icons.calendar_month,
                  color: AppColors.accent, size: isSmallScreen ? 14 : 16),
              label: Text("FULL CALENDAR",
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: isSmallScreen ? 9 : 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 10 : 12),
        _buildWeeklyCalendar(history, isSmallScreen),
        SizedBox(height: isSmallScreen ? 24 : 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("RECENT SESSIONS",
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: isSmallScreen ? 9 : 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            if (history.isNotEmpty)
              TextButton(
                onPressed: () => _showAllWorkoutsBottomSheet(context, history),
                child: Text("VIEW ALL",
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: isSmallScreen ? 9 : 10,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 10 : 12),
        if (history.isEmpty)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                      "No workouts logged yet.\nComplete a workout to see it here!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white24))))
        else
          ...history.take(5).map((w) => _buildHistoryCard(w, isSmallScreen)),
      ],
    );
  }

  Widget _buildWeeklyCalendar(List<CompletedWorkout> history, bool isSmallScreen) {
    final now = DateTime.now();
    final daysSinceSunday = now.weekday % 7;
    final startOfWeek = now.subtract(Duration(days: daysSinceSunday));

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          final date = startOfWeek.add(Duration(days: i));
          final isToday = date.day == now.day && date.month == now.month;
          final hasWorkout = history
              .any((w) => w.date.day == date.day && w.date.month == date.month);

          return Column(
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
              SizedBox(height: isSmallScreen ? 6 : 8),
              if (hasWorkout)
                Icon(Icons.local_fire_department,
                    color: AppColors.accent, size: isSmallScreen ? 24 : 28)
              else
                Container(
                  height: isSmallScreen ? 24 : 28,
                  width: isSmallScreen ? 24 : 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.accent.withValues(alpha: 0.1)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      fontWeight: FontWeight.bold,
                      color: isToday ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  void _showFullCalendarSheet(BuildContext context, List<CompletedWorkout> history) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _FullCalendarSheet(history: history),
    );
  }

  Widget _buildProgressTab(TrackerState state, Map<String, int> bodyParts, bool isSmallScreen) {
    return ListView(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      children: [
        Text("MUSCLE GROUP DISTRIBUTION",
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: isSmallScreen ? 9 : 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        SizedBox(height: isSmallScreen ? 10 : 12),
        _buildBodyPartHeatMap(bodyParts, isSmallScreen),
        SizedBox(height: isSmallScreen ? 24 : 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("BODY METRICS",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: isSmallScreen ? 13 : 14)),
            TextButton(
                onPressed: () => _showAddMetricDialog(),
                child: Text("ADD NEW",
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: isSmallScreen ? 10 : 11,
                        fontWeight: FontWeight.bold))),
          ],
        ),
        SizedBox(height: isSmallScreen ? 10 : 12),
        if (state.metrics.isEmpty)
          _buildEmptyBox(
            Icons.monitor_weight_outlined,
            "No metrics logged yet.\nTap + to add your weight.",
            isSmallScreen,
          )
        else ...[
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 24),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricDisplay(
                    'Weight',
                    '${state.metrics.first.weight} ${ref.watch(settingsProvider).weightUnit}',
                    Icons.monitor_weight,
                    isSmallScreen,
                  ),
                ),
                Container(height: 40, width: 1, color: Colors.white10),
                Expanded(
                  child: _buildMetricDisplay(
                    'Body Fat',
                    state.metrics.first.bodyFat.isNotEmpty
                        ? '${state.metrics.first.bodyFat}%'
                        : '--',
                    Icons.percent,
                    isSmallScreen,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 14 : 16),
          if (state.metrics.length > 1) ...[
            Container(
              height: 200,
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: state.metrics.reversed.toList().asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), double.tryParse(e.value.weight) ?? 0.0);
                      }).toList(),
                      isCurved: true,
                      color: AppColors.accent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 14 : 16),
          ],
          Text("HISTORY",
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: isSmallScreen ? 9 : 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          SizedBox(height: isSmallScreen ? 6 : 8),
          ...state.metrics.take(5).map((metric) => Container(
                margin: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${metric.date.day}/${metric.date.month}/${metric.date.year}',
                      style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 12 : 14),
                    ),
                    Row(
                      children: [
                        Text(
                          '${metric.weight} ${ref.watch(settingsProvider).weightUnit}',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 12 : 14),
                        ),
                        if (metric.bodyFat.isNotEmpty) ...[
                          const Text(' • ', style: TextStyle(color: Colors.white24)),
                          Text(
                            '${metric.bodyFat}%',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 12 : 14),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildBodyPartHeatMap(Map<String, int> bodyParts, bool isSmallScreen) {
    final maxCount = bodyParts.values.fold<int>(0, (max, v) => v > max ? v : max);
    final totalExercises = bodyParts.values.fold<int>(0, (sum, v) => sum + v);

    return Container(
      height: 320,
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 24),
        border: Border.all(color: AppColors.border),
      ),
      child: totalExercises == 0
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center, color: Colors.white24, size: 48),
                  SizedBox(height: 16),
                  Text("No exercises tracked yet",
                      style: TextStyle(color: Colors.white24)),
                ],
              ),
            )
          : Column(
              children: [
                Text(
                  "$totalExercises total exercises tracked",
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: isSmallScreen ? 11 : 12),
                ),
                Expanded(
                  child: RadarChart(
                    RadarChartData(
                      dataSets: [
                        RadarDataSet(
                          fillColor: AppColors.accent.withValues(alpha: 0.2),
                          borderColor: AppColors.accent,
                          entryRadius: 3,
                          dataEntries: _allMuscleGroups.map((muscle) {
                            return RadarEntry(
                                value: (bodyParts[muscle] ?? 0).toDouble());
                          }).toList(),
                          borderWidth: 2,
                        ),
                      ],
                      radarBackgroundColor: Colors.transparent,
                      borderData: FlBorderData(show: false),
                      radarBorderData: const BorderSide(color: Colors.white10),
                      titleTextStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: isSmallScreen ? 9 : 10),
                      getTitle: (index, angle) {
                        return RadarChartTitle(
                          text: _allMuscleGroups[index],
                        );
                      },
                      tickCount: 3,
                      ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 10),
                      tickBorderData: const BorderSide(color: Colors.white10),
                      gridBorderData: const BorderSide(color: Colors.white10, width: 2),
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 150),
                    swapAnimationCurve: Curves.linear,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHistoryCard(CompletedWorkout w, bool isSmallScreen) => GestureDetector(
        onTap: () => context.push('/tracker/history/${w.id}'),
        child: Container(
          margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                height: isSmallScreen ? 40 : 48,
                width: isSmallScreen ? 40 : 48,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                ),
                child: Icon(Icons.fitness_center,
                    color: AppColors.accent, size: isSmallScreen ? 20 : 24),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(w.date),
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 14 : 16),
                    ),
                    SizedBox(height: isSmallScreen ? 3 : 4),
                    Row(
                      children: [
                        Icon(Icons.timer,
                            color: AppColors.textSecondary, size: isSmallScreen ? 12 : 14),
                        SizedBox(width: 4),
                        Text(
                          "${w.durationSeconds ~/ 60} min",
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: isSmallScreen ? 11 : 12),
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Icon(Icons.fitness_center,
                            color: AppColors.textSecondary, size: isSmallScreen ? 12 : 14),
                        SizedBox(width: 4),
                        Text(
                          "${w.routine.length} exercises",
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: isSmallScreen ? 11 : 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white10),
            ],
          ),
        ),
      );

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'Today';
    } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildMetricDisplay(String label, String value, IconData icon, bool isSmallScreen) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: isSmallScreen ? 20 : 24),
        SizedBox(height: isSmallScreen ? 6 : 8),
        Text(value,
            style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.w900)),
        SizedBox(height: isSmallScreen ? 3 : 4),
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: isSmallScreen ? 10 : 11,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyBox(IconData icon, String text, bool isSmallScreen) => Container(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24)),
        child: Column(
          children: [
            Icon(icon, color: Colors.white24, size: isSmallScreen ? 36 : 40),
            SizedBox(height: isSmallScreen ? 10 : 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white24, fontSize: isSmallScreen ? 12 : 13)),
          ],
        ),
      );

  void _showAddMetricDialog() {
    final weightController = TextEditingController();
    final bfController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Add Body Metric',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Weight (${ref.read(settingsProvider).weightUnit})',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bfController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Body Fat % (optional)',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final weight = double.tryParse(weightController.text.replaceAll(",", "."));
              if (weight != null) {
                final bf = double.tryParse(bfController.text.replaceAll(",", "."));
                ref.read(trackerProvider.notifier).addBodyMetric(weight, bodyFat: bf);
                Navigator.pop(context);
              }
            },
            child: const Text('SAVE',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStatsBottomSheet(BuildContext context, TrackerState state) {
    final now = DateTime.now();
    final thisWeek = state.history
        .where((w) => w.date.isAfter(now.subtract(const Duration(days: 7))))
        .length;
    final thisMonth = state.history
        .where((w) => w.date.month == now.month && w.date.year == now.year)
        .length;
    final totalVolume = state.history.fold(0.0, (sum, w) => sum + w.totalVolume);
    final totalTime = state.history.fold(0, (sum, w) => sum + w.durationSeconds);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text('STATISTICS',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildStatCard('$thisWeek', 'This Week', Icons.calendar_today, false)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('$thisMonth', 'This Month', Icons.date_range, false)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard('${totalVolume.toInt()}', 'Total Volume', Icons.fitness_center, false)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('${(totalTime / 3600).toStringAsFixed(1)}h', 'Total Time', Icons.timer, false)),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showAllWorkoutsBottomSheet(BuildContext context, List<CompletedWorkout> history) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text('ALL WORKOUTS',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: history.length,
                  itemBuilder: (context, index) => _buildHistoryCard(history[index], false),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Full Calendar Sheet Widget
class _FullCalendarSheet extends StatefulWidget {
  final List<CompletedWorkout> history;
  const _FullCalendarSheet({required this.history});

  @override
  State<_FullCalendarSheet> createState() => _FullCalendarSheetState();
}

class _FullCalendarSheetState extends State<_FullCalendarSheet> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_currentMonth.year < now.year ||
        (_currentMonth.year == now.year && _currentMonth.month < now.month)) {
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      });
    }
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return _currentMonth.year < now.year ||
        (_currentMonth.year == now.year && _currentMonth.month < now.month);
  }

  List<int> _getWorkoutDays() {
    final days = <int>[];
    for (final workout in widget.history) {
      if (workout.date.month == _currentMonth.month &&
          workout.date.year == _currentMonth.year) {
        if (!days.contains(workout.date.day)) {
          days.add(workout.date.day);
        }
      }
    }
    return days;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final workoutDays = _getWorkoutDays();
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayOfWeek = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    final today = DateTime.now();
    final isCurrentMonth = _currentMonth.month == today.month && _currentMonth.year == today.year;

    final List<Widget> dayWidgets = [];
    for (int i = 0; i < firstDayOfWeek; i++) {
      dayWidgets.add(const SizedBox(width: 36, height: 44));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final isToday = isCurrentMonth && day == today.day;
      final hasWorkout = workoutDays.contains(day);

      dayWidgets.add(
        Container(
          width: 36, height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday
                ? AppColors.accent.withValues(alpha: 0.2)
                : hasWorkout
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isToday ? Border.all(color: AppColors.accent, width: 1.5) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day',
                  style: TextStyle(
                    color: isToday ? AppColors.accent : hasWorkout ? Colors.white : Colors.white38,
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w500,
                  )),
              if (hasWorkout)
                Container(
                  width: 5, height: 5,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: _previousMonth,
                    ),
                    Text(
                      '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right,
                          color: _canGoNext ? Colors.white : Colors.white24),
                      onPressed: _canGoNext ? _nextMonth : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                            .map((d) => SizedBox(
                                  width: 36,
                                  child: Text(d,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 0, runSpacing: 4,
                        alignment: WrapAlignment.start,
                        children: dayWidgets,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text("WORKOUTS THIS MONTH",
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                const SizedBox(height: 12),
                ...widget.history
                    .where((w) => w.date.month == _currentMonth.month &&
                        w.date.year == _currentMonth.year)
                    .map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildMiniHistoryCard(w, context),
                        )),
                if (widget.history
                    .where((w) => w.date.month == _currentMonth.month &&
                        w.date.year == _currentMonth.year)
                    .isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("No workouts this month.",
                        style: TextStyle(color: Colors.white24)),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniHistoryCard(CompletedWorkout w, BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        context.push('/tracker/history/${w.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              height: 48, width: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.fitness_center, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${w.date.day}/${w.date.month}/${w.date.year}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("${w.durationSeconds ~/ 60} min • ${w.routine.length} exercises",
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white10),
          ],
        ),
      ),
    );
  }
}