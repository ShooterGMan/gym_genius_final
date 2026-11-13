import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import '../models/exercise.dart';
import '../providers/exercise_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tracker_provider.dart';
import '../services/data_export_service.dart';
import '../services/workout_stats.dart';
import '../theme/app_theme.dart';

class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  const WorkoutSummaryScreen({super.key});

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  final _shot = ScreenshotController();
  bool _sharing = false;

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}H ${m}M';
    return '${m < 1 ? '<1' : m} MIN';
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _shot.capture(pixelRatio: 3);
      if (bytes == null) throw Exception('capture failed');
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/gymgenius_workout_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes, flush: true);
      if (!buttonContext.mounted) return;
      await DataExportService.shareFile(
        buttonContext,
        file,
        text: 'Just finished a workout with GymGenius 💪',
        mimeType: 'image/png',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't create the share image."),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackerState = ref.watch(trackerProvider);
    if (trackerState.history.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text('Back to Dashboard'),
          ),
        ),
      );
    }

    final latestWorkout = trackerState.history.first;
    final unit = ref.watch(settingsProvider).weightUnit.toUpperCase();
    final exercises = ref.watch(exercisesProvider).value ?? const <Exercise>[];
    final byId = {for (final e in exercises) e.id: e};
    String nameOf(String id) => byId[id]?.name ?? id.replaceAll('_', ' ');

    final totalSets = latestWorkout.totalSets;
    final prs = prsInWorkout(latestWorkout, trackerState.history);

    // Best set of up to 4 exercises for the card.
    final highlights = <MapEntry<String, String>>[];
    for (final ex in latestWorkout.routine) {
      final session = ExerciseSession(
        workoutId: latestWorkout.id,
        date: latestWorkout.date,
        mode: ex.logMode,
        sets: ex.sets.where((s) => s.isCompleted).toList(),
      );
      final best = session.bestSet;
      if (best == null) continue;
      highlights.add(MapEntry(nameOf(ex.exerciseId), formatSet(best, ex.logMode)));
      if (highlights.length == 4) break;
    }

    final d = latestWorkout.date;
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];

    final card = Container(
      // Opaque backdrop so the exported PNG has no transparent corners.
      color: AppColors.background,
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt, color: AppColors.accent, size: 28),
                SizedBox(width: 8),
                Text(
                  "GYMGENIUS",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (latestWorkout.name != null) ...[
              Text(
                latestWorkout.name!.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              prs.isNotEmpty ? "New Record${prs.length == 1 ? '' : 's'}!" : "Great Job!",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${d.day} ${months[d.month - 1]} ${d.year}",
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn("DURATION", _formatDuration(latestWorkout.durationSeconds)),
                Container(width: 1, height: 40, color: Colors.white10),
                _buildStatColumn("VOLUME", "${latestWorkout.totalVolume.toStringAsFixed(0)} $unit"),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn("EXERCISES", "${latestWorkout.routine.length}"),
                Container(width: 1, height: 40, color: Colors.white10),
                _buildStatColumn("SETS", "$totalSets"),
              ],
            ),
            if (prs.isNotEmpty) ...[
              const SizedBox(height: 24),
              ...prs.take(3).map((pr) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.emoji_events, color: AppColors.accent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(nameOf(pr.exerciseId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      Text(
                        pr.kind == 'e1rm'
                            ? '${pr.setText} · ~${fmtNum(pr.value)} 1RM'
                            : pr.setText,
                        style: const TextStyle(
                            color: AppColors.accent, fontWeight: FontWeight.bold),
                      ),
                    ]),
                  )),
            ] else if (highlights.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 16),
              ...highlights.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                        child: Text(h.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70)),
                      ),
                      Text(h.value,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ]),
                  )),
            ],
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  const Text(
                    "WORKOUT COMPLETE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => context.go('/dashboard'),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Screenshot(controller: _shot, child: card),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: Builder(
                        builder: (btnContext) => OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.accent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _sharing
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  _share(btnContext);
                                },
                          icon: _sharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.accent))
                              : const Icon(Icons.ios_share, color: AppColors.accent),
                          label: const Text(
                            "SHARE",
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => context.go('/dashboard'),
                        child: const Text(
                          "DONE",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
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

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
