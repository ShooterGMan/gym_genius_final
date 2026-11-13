import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/active_workout_provider.dart';
import '../providers/settings_provider.dart';
import '../services/workout_stats.dart';
import '../theme/app_theme.dart';

/// "Your progress" block on the exercise details screen: headline stats,
/// estimated-1RM (or max reps) trend, and recent sessions.
class ExerciseProgressSection extends ConsumerWidget {
  final String exerciseId;
  const ExerciseProgressSection({super.key, required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(exerciseSessionsProvider(exerciseId));
    if (sessions.isEmpty) return const SizedBox.shrink();
    final unit = ref.watch(settingsProvider).weightUnit;

    // Chart the dominant log mode for this exercise.
    final weighted = sessions.where((s) => s.mode == LogMode.weightAndReps).toList();
    final usesWeight = weighted.length * 2 >= sessions.length;
    final chartSessions = (usesWeight
            ? weighted
            : sessions.where((s) => s.mode == LogMode.repsOnly).toList())
        .take(20)
        .toList()
        .reversed
        .toList(); // oldest -> newest

    double metric(ExerciseSession s) =>
        usesWeight ? s.bestE1RM : s.maxReps.toDouble();

    final best = sessions.fold<double>(0, (m, s) => s.bestE1RM > m ? s.bestE1RM : m);
    final heaviest = sessions.fold<double>(0, (m, s) => s.topWeight > m ? s.topWeight : m);
    final maxReps = sessions.fold<int>(0, (m, s) => s.maxReps > m ? s.maxReps : m);

    final spots = <FlSpot>[
      for (var i = 0; i < chartSessions.length; i++)
        if (metric(chartSessions[i]) > 0)
          FlSpot(i.toDouble(), metric(chartSessions[i]))
    ];

    String? trend;
    if (spots.length >= 2) {
      final diff = spots.last.y - spots.first.y;
      final sign = diff >= 0 ? '+' : '−';
      trend = '$sign${fmtNum(diff.abs())} ${usesWeight ? unit : 'reps'} '
          'over ${spots.length} sessions';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('YOUR PROGRESS',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(height: 16),
        Row(children: [
          if (usesWeight) ...[
            _stat('BEST EST. 1RM', '${fmtNum(best)} $unit'),
            const SizedBox(width: 8),
            _stat('HEAVIEST', '${fmtNum(heaviest)} $unit'),
          ] else
            _stat('MOST REPS', '$maxReps'),
          const SizedBox(width: 8),
          _stat('SESSIONS', '${sessions.length}'),
        ]),
        if (spots.length >= 2) ...[
          const SizedBox(height: 16),
          Container(
            height: 180,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        fmtNum(value, decimals: 0),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: AppColors.accent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.accent.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${usesWeight ? 'Estimated 1-rep max per session' : 'Max reps per session'}'
            '${trend != null ? '  ·  $trend' : ''}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
        const SizedBox(height: 20),
        const Text('RECENT SESSIONS',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        const SizedBox(height: 8),
        ...sessions.take(5).map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Text('${s.date.day}/${s.date.month}/${s.date.year % 100}',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  Expanded(
                    child: Text(
                      s.sets
                          .map((x) =>
                              '${x.type == SetType.warmup ? 'W ' : ''}${formatSet(x, s.mode)}'
                              '${x.rpe != null ? ' @${fmtNum(x.rpe!)}' : ''}')
                          .join('   '),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  if (s.bestE1RM > 0)
                    Text('~${fmtNum(s.bestE1RM)}',
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                ],
              ),
            )),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      );
}
