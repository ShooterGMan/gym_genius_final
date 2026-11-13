import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/active_workout_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/settings_provider.dart';
import '../models/exercise.dart';
import '../theme/app_theme.dart';
import '../widgets/routine_selector_bottom_sheet.dart';
import '../services/workout_stats.dart';

class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutState = ref.watch(activeWorkoutProvider);
    final notifier = ref.read(activeWorkoutProvider.notifier);
    final allExercisesAsync = ref.watch(exercisesProvider);
    final unit = ref.watch(settingsProvider).weightUnit.toUpperCase();

    // Session ended elsewhere (e.g. discarded) - don't show a dead screen.
    if (!workoutState.isActive) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('No active workout',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () => context.go('/dashboard'),
              child: const Text('Back to dashboard',
                  style: TextStyle(color: Colors.black)),
            ),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  IconButton(
                      tooltip: 'Minimise',
                      icon: const Icon(Icons.keyboard_arrow_down,
                          size: 32, color: Colors.white),
                      onPressed: () => _close(context)),
                  Expanded(
                    child: Column(children: [
                      Text(
                          (workoutState.name ?? 'Active session').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2)),
                      Text(notifier.formatTime(workoutState.elapsedSeconds),
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 16,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    color: AppColors.surface,
                    onSelected: (v) {
                      if (v == 'discard') _confirmDiscard(context, ref);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'discard',
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Discard workout',
                              style: TextStyle(color: Colors.redAccent)),
                        ]),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                      onPressed: () => _handleFinishWorkout(context, ref),
                      child: const Text("FINISH",
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            if (workoutState.isResting)
              _buildRestTimerBar(context, workoutState, notifier),
            Expanded(
              child: allExercisesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent)),
                error: (err, stack) => const Center(
                    child: Text('Could not load exercises',
                        style: TextStyle(color: Colors.white70))),
                data: (allExercises) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (workoutState.routine.isEmpty)
                      Center(
                          child: Padding(
                              padding: const EdgeInsets.only(top: 100),
                              child: Column(children: [
                                const Icon(Icons.fitness_center,
                                    size: 64, color: Colors.white24),
                                const SizedBox(height: 16),
                                const Text("Empty Workout",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                const Text(
                                    "Add an exercise to start logging sets.",
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () => context.push('/workout/add'),
                                  icon: const Icon(Icons.add,
                                      color: Colors.black),
                                  label: const Text(
                                    "ADD FIRST EXERCISE",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                )
                              ]))),
                    ...() {
                      final ss = _supersetLabels(workoutState.routine);
                      return workoutState.routine.asMap().entries.map((entry) {
                        final liveEx = entry.value;
                        final exercise =
                            _findExercise(allExercises, liveEx.exerciseId);
                        final next = entry.key + 1 < workoutState.routine.length
                            ? workoutState.routine[entry.key + 1]
                            : null;
                        final linkedToNext = liveEx.supersetId != null &&
                            next?.supersetId == liveEx.supersetId;
                        return _buildLiveExerciseBlock(context, ref, entry.key,
                            liveEx, exercise, unit,
                            supersetLabel: ss[liveEx.id],
                            linkedToNext: linkedToNext,
                            isLast: next == null);
                      });
                    }(),
                    if (workoutState.routine.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => context.push('/workout/add'),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(24)),
                            child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, color: AppColors.accent),
                                  SizedBox(width: 8),
                                  Text("Add Exercise",
                                      style: TextStyle(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16))
                                ])),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "A1", "A2", "B1"… for exercises that are part of a superset.
  static Map<String, String> _supersetLabels(List<WorkoutExerciseLive> list) {
    final letters = <String, String>{};
    final counters = <String, int>{};
    final out = <String, String>{};
    for (final e in list) {
      final g = e.supersetId;
      if (g == null) continue;
      letters.putIfAbsent(
          g, () => String.fromCharCode(65 + letters.length % 26));
      counters[g] = (counters[g] ?? 0) + 1;
      out[e.id] = '${letters[g]}${counters[g]}';
    }
    return out;
  }

  static Exercise _findExercise(List<Exercise> all, String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    // Never show a *different* exercise when one is missing from the DB.
    return Exercise(
      id: id,
      name: id.replaceAll('_', ' '),
      equipment: '',
      level: '',
      primaryMuscles: const [],
      secondaryMuscles: const [],
      category: '',
      images: const [],
      instructions: const [],
    );
  }

  Widget _buildRestTimerBar(BuildContext context, ActiveWorkoutState state,
      ActiveWorkoutNotifier notifier) {
    final progress = state.restSecondsTotal > 0
        ? (state.restSeconds / state.restSecondsTotal).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.timer, color: AppColors.accent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "REST",
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                notifier.formatTime(state.restSeconds),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 32,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Flexible so the row never overflows on narrow phones.
          Row(
            children: [
              _buildTimerButton(notifier, "-15s", -15, Colors.orangeAccent),
              const SizedBox(width: 8),
              _buildTimerButton(notifier, "+15s", 15, Colors.lightGreenAccent),
              const SizedBox(width: 8),
              _buildTimerButton(notifier, "+30s", 30, Colors.greenAccent),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                            color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => notifier.skipRest(),
                    icon: const Icon(Icons.skip_next,
                        color: AppColors.accent, size: 16),
                    label: const Text(
                      "SKIP",
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerButton(
      ActiveWorkoutNotifier notifier, String label, int seconds, Color color) {
    return Expanded(
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticFeedback.selectionClick();
              notifier.adjustRestTimer(seconds);
            },
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveExerciseBlock(BuildContext context, WidgetRef ref,
      int index, WorkoutExerciseLive liveEx, Exercise ex, String unit,
      {String? supersetLabel, bool linkedToNext = false, bool isLast = false}) {
    final notifier = ref.read(activeWorkoutProvider.notifier);
    final sessions = ref.watch(exerciseSessionsProvider(liveEx.exerciseId));
    final previous = sessions.isNotEmpty ? sessions.first : null;
    final bestE1RM = sessions.fold<double>(
        0, (m, s) => s.bestE1RM > m ? s.bestE1RM : m);

    final imagePath = ex.images.isNotEmpty
        ? 'assets/images/${ex.images[0].replaceAll('/', '_')}'
        : '';

    String label1 = unit;
    String label2 = "REPS";
    if (liveEx.logMode == LogMode.repsOnly) {
      label1 = "";
      label2 = "REPS";
    } else if (liveEx.logMode == LogMode.timeAndReps) {
      label1 = "TIME";
      label2 = "REPS";
    } else if (liveEx.logMode == LogMode.timeAndDistance) {
      label1 = "TIME";
      label2 = "DIST";
    }

    const headerStyle = TextStyle(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.bold);

    // "Last time" summary + best estimated 1RM.
    String? lastLine;
    if (previous != null) {
      final sets = previous.sets
          .where((s) => s.isWorking)
          .map((s) => formatSet(s, previous.mode))
          .toList();
      final daysAgo = DateTime.now().difference(previous.date).inDays;
      final when = daysAgo == 0
          ? 'today'
          : daysAgo == 1
              ? 'yesterday'
              : '$daysAgo days ago';
      lastLine = 'Last ($when): ${sets.take(5).join(', ')}'
          '${sets.length > 5 ? '…' : ''}';
    }

    // Number working sets 1,2,3…; special sets show W / D / F instead.
    var workingNo = 0;
    final setLabels = <String>[
      for (final s in liveEx.sets)
        s.type == SetType.warmup ? s.type.marker : '${++workingNo}'
    ];

    final inSuperset = supersetLabel != null;

    return Container(
      margin: EdgeInsets.only(bottom: linkedToNext ? 8 : 24),
      padding: inSuperset ? const EdgeInsets.only(left: 12) : EdgeInsets.zero,
      decoration: inSuperset
          ? const BoxDecoration(
              border: Border(
                  left: BorderSide(color: AppColors.accent, width: 3)))
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (inSuperset)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('SUPERSET $supersetLabel',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5)),
          ),
        Row(children: [
          Expanded(
              child: GestureDetector(
                  onTap: ex.instructions.isEmpty
                      ? null
                      : () => context.push('/exercise/${ex.id}'),
                  child: Row(children: [
                    Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                            image: imagePath.isNotEmpty
                                ? DecorationImage(
                                    image: AssetImage(imagePath),
                                    fit: BoxFit.cover)
                                : null),
                        child: imagePath.isEmpty
                            ? const Icon(Icons.fitness_center,
                                color: Colors.white24)
                            : null),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(ex.name,
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(
                              [
                                if (ex.primaryMuscles.isNotEmpty)
                                  ex.primaryMuscles[0].toUpperCase(),
                                if (liveEx.targetReps != null)
                                  'TARGET ${liveEx.targetReps!.toUpperCase()}',
                                if (bestE1RM > 0 && liveEx.tracksWeight)
                                  'BEST 1RM ~${fmtNum(bestE1RM)}',
                              ].join('  •  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  letterSpacing: 1))
                        ])),
                  ]))),
          PopupMenuButton<String>(
            tooltip: 'Exercise options',
            icon: const Icon(Icons.more_vert,
                color: AppColors.textSecondary, size: 20),
            color: AppColors.surface,
            onSelected: (value) {
              switch (value) {
                case 'up':
                  notifier.moveExercise(index, index - 1);
                  break;
                case 'down':
                  notifier.moveExercise(index, index + 1);
                  break;
                case 'superset':
                  notifier.supersetWithNext(liveEx.id);
                  break;
                case 'unsuperset':
                  notifier.removeFromSuperset(liveEx.id);
                  break;
                case 'program':
                  showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => RoutineSelectorBottomSheet(
                          exerciseId: ex.id, exerciseName: ex.name));
                  break;
                case 'remove':
                  _removeExercise(context, ref, index, liveEx, ex.name);
                  break;
                default:
                  final mode = LogMode.values.firstWhere(
                      (m) => m.name == value,
                      orElse: () => liveEx.logMode);
                  notifier.setLogMode(liveEx.id, mode);
              }
            },
            itemBuilder: (context) => [
              _modeItem(LogMode.weightAndReps, "Weight & Reps", liveEx.logMode),
              _modeItem(LogMode.repsOnly, "Reps Only", liveEx.logMode),
              _modeItem(LogMode.timeAndReps, "Time & Reps", liveEx.logMode),
              _modeItem(
                  LogMode.timeAndDistance, "Time & Distance", liveEx.logMode),
              const PopupMenuDivider(),
              if (!isLast && !linkedToNext)
                const PopupMenuItem(
                    value: 'superset',
                    child: Text("Superset with next",
                        style: TextStyle(fontSize: 13))),
              if (inSuperset)
                const PopupMenuItem(
                    value: 'unsuperset',
                    child: Text("Remove from superset",
                        style: TextStyle(fontSize: 13))),
              if (index > 0)
                const PopupMenuItem(
                    value: 'up',
                    child: Text("Move up", style: TextStyle(fontSize: 13))),
              if (!isLast)
                const PopupMenuItem(
                    value: 'down',
                    child: Text("Move down", style: TextStyle(fontSize: 13))),
              const PopupMenuItem(
                  value: 'program',
                  child: Text("Add to a program",
                      style: TextStyle(fontSize: 13))),
              const PopupMenuItem(
                  value: 'remove',
                  child: Text("Remove exercise",
                      style: TextStyle(fontSize: 13, color: Colors.redAccent))),
            ],
          ),
        ]),
        if (lastLine != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(lastLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ),
        const SizedBox(height: 12),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              const SizedBox(width: 30, child: Text("SET", style: headerStyle)),
              const SizedBox(
                  width: 62,
                  child: Text("PREV",
                      textAlign: TextAlign.center, style: headerStyle)),
              if (label1.isNotEmpty)
                Expanded(
                    child: Text(label1,
                        textAlign: TextAlign.center, style: headerStyle)),
              Expanded(
                  child: Text(label2,
                      textAlign: TextAlign.center, style: headerStyle)),
              const SizedBox(
                  width: 40,
                  child: Text("DONE",
                      textAlign: TextAlign.center, style: headerStyle)),
            ])),
        const SizedBox(height: 8),
        ...liveEx.sets.asMap().entries.map((entry) {
          final set = entry.value;
          final prevSet = previous != null &&
                  previous.mode == liveEx.logMode &&
                  entry.key < previous.sets.length
              ? previous.sets[entry.key]
              : null;
          return Dismissible(
            key: ValueKey('dismiss_${set.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.only(right: 20),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
            onDismissed: (_) {
              HapticFeedback.lightImpact();
              notifier.removeSet(liveEx.id, set.id);
            },
            child: _SetRow(
              key: ValueKey(set.id),
              liveExId: liveEx.id,
              setItem: set,
              label: setLabels[entry.key],
              notifier: notifier,
              logMode: liveEx.logMode,
              repsHint: liveEx.targetReps,
              prevText:
                  prevSet != null ? formatSet(prevSet, liveEx.logMode) : null,
              onPrevTap: prevSet == null || set.isCompleted
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      notifier.fillSet(liveEx.id, set.id,
                          weight: prevSet.weight, reps: prevSet.reps);
                    },
              onLabelTap: () => _showSetOptions(context, ref, liveEx, set),
            ),
          );
        }),
        Row(children: [
          TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                notifier.addSet(liveEx.id);
              },
              icon: const Icon(Icons.add,
                  color: AppColors.textSecondary, size: 16),
              label: const Text("Add Set",
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          const Spacer(),
          if (liveEx.sets.isNotEmpty)
            const Flexible(
              child: Text("Tap set # for type / RPE · swipe to delete",
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white24, fontSize: 10)),
            ),
        ]),
      ]),
    );
  }

  /// Bottom sheet to change a set's type (warm-up / drop / failure) and RPE.
  void _showSetOptions(BuildContext context, WidgetRef ref,
      WorkoutExerciseLive liveEx, LiveSet set) {
    final notifier = ref.read(activeWorkoutProvider.notifier);
    const rpeValues = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        // Re-read the live set so chips reflect changes immediately.
        final ex = ref
            .watch(activeWorkoutProvider)
            .routine
            .where((e) => e.id == liveEx.id);
        final current = ex.isEmpty
            ? set
            : ex.first.sets.firstWhere((s) => s.id == set.id,
                orElse: () => set);

        Widget chip(String label, bool selected, VoidCallback onTap,
                {Color color = AppColors.accent}) =>
            ChoiceChip(
              label: Text(label),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                onTap();
              },
              selectedColor: color,
              backgroundColor: AppColors.background,
              side: BorderSide(color: selected ? color : AppColors.border),
              labelStyle: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold),
            );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SET TYPE',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in SetType.values)
                    chip(t.label, current.type == t,
                        () => notifier.setSetType(liveEx.id, set.id, t),
                        color: _setTypeColor(t)),
                ]),
                const SizedBox(height: 6),
                const Text(
                    'Warm-up sets don’t count toward volume or personal records.',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 20),
                const Text('RPE  (how hard was it?)',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 8, children: [
                  chip('—', current.rpe == null,
                      () => notifier.setRpe(liveEx.id, set.id, null)),
                  for (final v in rpeValues)
                    chip(fmtNum(v), current.rpe == v,
                        () => notifier.setRpe(liveEx.id, set.id, v)),
                ]),
                const SizedBox(height: 6),
                const Text('10 = nothing left · 8 = two reps in reserve',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        );
      }),
    );
  }

  static Color _setTypeColor(SetType t) {
    switch (t) {
      case SetType.normal:
        return AppColors.accent;
      case SetType.warmup:
        return Colors.orangeAccent;
      case SetType.drop:
        return Colors.purpleAccent;
      case SetType.failure:
        return Colors.redAccent;
    }
  }

  PopupMenuItem<String> _modeItem(LogMode mode, String label, LogMode current) {
    return PopupMenuItem(
      value: mode.name,
      child: Row(children: [
        Icon(mode == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 16,
            color: mode == current ? AppColors.accent : AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }

  void _removeExercise(BuildContext context, WidgetRef ref, int index,
      WorkoutExerciseLive liveEx, String name) {
    final notifier = ref.read(activeWorkoutProvider.notifier);
    notifier.removeExercise(liveEx.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('Removed $name',
            style: const TextStyle(color: Colors.white)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.accent,
          onPressed: () => notifier.insertExercise(index, liveEx),
        ),
      ));
  }

  void _confirmDiscard(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Discard workout?",
            style: TextStyle(color: Colors.white)),
        content: const Text(
            "Nothing from this session will be saved. This can't be undone.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Keep training")),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(activeWorkoutProvider.notifier).discardWorkout();
                context.go('/dashboard');
              },
              child: const Text("Discard",
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  void _handleFinishWorkout(BuildContext context, WidgetRef ref) {
    FocusScope.of(context).unfocus();
    final session = ref.read(activeWorkoutProvider);
    final done = session.completedSetCount;
    final total =
        session.routine.fold<int>(0, (sum, ex) => sum + ex.sets.length);

    if (done == 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text("No completed sets",
              style: TextStyle(color: Colors.white)),
          content: const Text(
              "Tap ✓ next to each set you've done so it gets logged, or discard this workout.",
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmDiscard(context, ref);
                },
                child: const Text("Discard",
                    style: TextStyle(color: Colors.redAccent))),
            ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Keep training",
                    style: TextStyle(color: Colors.black))),
          ],
        ),
      );
      return;
    }

    final skipped = total - done;
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text("Finish workout?",
                  style: TextStyle(color: Colors.white)),
              content: Text(
                  skipped > 0
                      ? "$done set${done == 1 ? '' : 's'} will be logged. $skipped unchecked set${skipped == 1 ? '' : 's'} will be skipped."
                      : "All $done sets will be logged.",
                  style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Keep training")),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final saved = await ref
                          .read(trackerProvider.notifier)
                          .saveWorkout(ref.read(activeWorkoutProvider));
                      ref.read(activeWorkoutProvider.notifier).endWorkout();
                      HapticFeedback.heavyImpact();
                      if (!context.mounted) return;
                      context.go(saved != null
                          ? '/summary'
                          : '/dashboard');
                    },
                    child: const Text("Finish",
                        style: TextStyle(color: Colors.black))),
              ],
            ));
  }
}

class _SetRow extends StatefulWidget {
  final String liveExId;
  final LiveSet setItem;
  final String label;
  final ActiveWorkoutNotifier notifier;
  final LogMode logMode;
  final String? repsHint;
  final String? prevText;
  final VoidCallback? onPrevTap;
  final VoidCallback onLabelTap;

  const _SetRow({
    super.key,
    required this.liveExId,
    required this.setItem,
    required this.label,
    required this.notifier,
    required this.logMode,
    required this.onLabelTap,
    this.repsHint,
    this.prevText,
    this.onPrevTap,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late TextEditingController weightCtrl;
  late TextEditingController repsCtrl;

  @override
  void initState() {
    super.initState();
    weightCtrl = TextEditingController(text: widget.setItem.weight);
    repsCtrl = TextEditingController(text: widget.setItem.reps);
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (weightCtrl.text != widget.setItem.weight) {
      weightCtrl.text = widget.setItem.weight;
    }
    if (repsCtrl.text != widget.setItem.reps) {
      repsCtrl.text = widget.setItem.reps;
    }
  }

  @override
  void dispose() {
    weightCtrl.dispose();
    repsCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint, bool isDone) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
      filled: true,
      fillColor: isDone ? Colors.transparent : Colors.black12,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10));

  Color get _labelColor {
    switch (widget.setItem.type) {
      case SetType.warmup:
        return Colors.orangeAccent;
      case SetType.drop:
        return Colors.purpleAccent;
      case SetType.failure:
        return Colors.redAccent;
      case SetType.normal:
        return widget.setItem.isCompleted
            ? AppColors.accent
            : AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.setItem;
    final isDone = set.isCompleted;
    final bool isTimeBased = widget.logMode == LogMode.timeAndReps ||
        widget.logMode == LogMode.timeAndDistance;
    final bool showFirstField = widget.logMode != LogMode.repsOnly;
    final textStyle = TextStyle(
        color: isDone ? AppColors.accent : Colors.white,
        fontWeight: FontWeight.bold);

    final repsHint = widget.logMode == LogMode.timeAndDistance
        ? "km"
        : (widget.repsHint != null && widget.repsHint!.length <= 6
            ? widget.repsHint!
            : "0");

    // Drop / failure sets show their marker next to the number.
    final marker = set.type == SetType.drop || set.type == SetType.failure
        ? set.type.marker
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: isDone ? AppColors.accent.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDone
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : Colors.transparent)),
      child: Row(children: [
        // Set number / type - tap for type & RPE.
        InkWell(
          onTap: widget.onLabelTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 30,
            height: 40,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.label}$marker',
                    style: TextStyle(
                        color: _labelColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                if (set.rpe != null)
                  Text('@${fmtNum(set.rpe!)}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 9)),
              ],
            ),
          ),
        ),
        // Previous session's matching set - tap to copy it.
        SizedBox(
          width: 62,
          child: InkWell(
            onTap: widget.onPrevTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                widget.prevText ?? '—',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: widget.onPrevTap != null
                        ? Colors.white54
                        : Colors.white24,
                    fontSize: 11),
              ),
            ),
          ),
        ),
        if (showFirstField)
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                      controller: weightCtrl,
                      keyboardType: isTimeBased
                          ? TextInputType.datetime
                          : const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      textAlign: TextAlign.center,
                      style: textStyle,
                      decoration: _decoration(isTimeBased ? "mm:ss" : "0", isDone),
                      enabled: !isDone,
                      onChanged: (val) => widget.notifier.updateSet(
                          widget.liveExId,
                          set.id,
                          'weight',
                          // Some locales' keyboards emit "," as decimal separator.
                          isTimeBased ? val : val.replaceAll(',', '.'))))),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                    controller: repsCtrl,
                    keyboardType: widget.logMode == LogMode.timeAndDistance
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    style: textStyle,
                    decoration: _decoration(repsHint, isDone),
                    enabled: !isDone,
                    onChanged: (val) => widget.notifier.updateSet(
                        widget.liveExId,
                        set.id,
                        'reps',
                        val.replaceAll(',', '.'))))),
        SizedBox(
            width: 40,
            child: IconButton(
                tooltip: isDone ? 'Mark as not done' : 'Mark set done',
                icon: Icon(
                    isDone ? Icons.check_circle : Icons.check_circle_outline,
                    color: isDone ? AppColors.accent : AppColors.textSecondary),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  widget.notifier.toggleSetComplete(widget.liveExId, set.id);
                })),
      ]),
    );
  }
}
