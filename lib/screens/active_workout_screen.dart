import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/active_workout_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/settings_provider.dart';
import '../models/exercise.dart';
import '../theme/app_theme.dart';
import '../widgets/routine_selector_bottom_sheet.dart';

class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutState = ref.watch(activeWorkoutProvider);
    final notifier = ref.read(activeWorkoutProvider.notifier);
    final allExercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down,
                          size: 32, color: Colors.white),
                      onPressed: () => context.pop()),
                  Column(children: [
                    const Text("ACTIVE SESSION",
                        style: TextStyle(
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
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20))),
                    onPressed: () =>
                        _handleFinishWorkout(context, ref, notifier),
                    child: const Text("FINISH",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
            if (workoutState.isResting)
              _buildRestTimerBar(context, ref, workoutState, notifier),
            Expanded(
              child: allExercisesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent)),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (allExercises) => ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (workoutState.routine.isEmpty)
                      const Center(
                          child: Padding(
                              padding: EdgeInsets.only(top: 100),
                              child: Column(children: [
                                Icon(Icons.fitness_center,
                                    size: 64, color: AppColors.surface),
                                SizedBox(height: 16),
                                Text("Empty Workout",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold))
                              ]))),
                    ...workoutState.routine.map((liveEx) {
                      final exercise = allExercises.firstWhere(
                          (e) => e.id == liveEx.exerciseId,
                          orElse: () => allExercises.first);
                      return _buildLiveExerciseBlock(
                          context, ref, liveEx, exercise);
                    }),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: () => context.push('/workout/add'),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.05),
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

  Widget _buildRestTimerBar(BuildContext context, WidgetRef ref,
      ActiveWorkoutState state, ActiveWorkoutNotifier notifier) {
    final progress = state.restSecondsTotal > 0
        ? state.restSeconds / state.restSecondsTotal
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          // Timer display with progress bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer,
                            color: AppColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "REST PERIOD",
                          style: const TextStyle(
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
              // Timer display
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

          // Quick adjustment buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimerButton(notifier, "-30s", -30, Colors.redAccent),
              _buildTimerButton(notifier, "-15s", -15, Colors.orangeAccent),
              _buildTimerButton(notifier, "+15s", 15, Colors.lightGreenAccent),
              _buildTimerButton(notifier, "+30s", 30, Colors.greenAccent),
              // Skip button
              Container(
                height: 36,
                margin: const EdgeInsets.only(left: 8),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side:
                          BorderSide(color: AppColors.accent.withOpacity(0.3)),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => notifier.skipRest(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.skip_next, color: AppColors.accent, size: 16),
                      SizedBox(width: 4),
                      Text(
                        "SKIP",
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => notifier.adjustRestTimer(seconds),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
      WorkoutExerciseLive liveEx, Exercise ex) {
    final notifier = ref.read(activeWorkoutProvider.notifier);

    final imagePath = ex.images.isNotEmpty
        ? 'assets/images/${ex.images[0].replaceAll('/', '_')}'
        : '';

    String label1 = "WEIGHT";
    String label2 = "REPS";
    if (liveEx.logMode == LogMode.repsOnly) {
      label1 = "REPS";
      label2 = "";
    } else if (liveEx.logMode == LogMode.timeAndReps) {
      label1 = "TIME";
      label2 = "REPS";
    } else if (liveEx.logMode == LogMode.timeAndDistance) {
      label1 = "TIME";
      label2 = "DIST";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: GestureDetector(
                  onTap: () => context.push('/library/exercise/${ex.id}'),
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
                              ex.primaryMuscles.isNotEmpty
                                  ? ex.primaryMuscles[0].toUpperCase()
                                  : "TARGET",
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  letterSpacing: 1))
                        ])),
                  ]))),
          PopupMenuButton<LogMode>(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.textSecondary, size: 20),
            color: AppColors.surface,
            onSelected: (mode) => notifier.setLogMode(liveEx.id, mode),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: LogMode.repsOnly,
                  child: Text("Reps Only", style: TextStyle(fontSize: 12))),
              const PopupMenuItem(
                  value: LogMode.weightAndReps,
                  child: Text("Weight & Reps", style: TextStyle(fontSize: 12))),
              const PopupMenuItem(
                  value: LogMode.timeAndReps,
                  child: Text("Time & Reps", style: TextStyle(fontSize: 12))),
              const PopupMenuItem(
                  value: LogMode.timeAndDistance,
                  child:
                      Text("Time & Distance", style: TextStyle(fontSize: 12))),
            ],
          ),
          IconButton(
              icon: const Icon(Icons.playlist_add,
                  color: AppColors.textSecondary, size: 20),
              onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => RoutineSelectorBottomSheet(
                      exerciseId: ex.id, exerciseName: ex.name))),
        ]),
        const SizedBox(height: 16),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const SizedBox(
                  width: 30,
                  child: Text("SET",
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text(label1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold))),
              if (label2.isNotEmpty)
                Expanded(
                    child: Text(label2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold))),
              const SizedBox(
                  width: 40,
                  child: Text("DONE",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold))),
            ])),
        const SizedBox(height: 8),
        ...liveEx.sets.asMap().entries.map((entry) => _SetRow(
            key: ValueKey(entry.value.id),
            liveExId: liveEx.id,
            setItem: entry.value,
            index: entry.key,
            notifier: notifier,
            logMode: liveEx.logMode)),
        TextButton.icon(
            onPressed: () => notifier.addSet(liveEx.id),
            icon:
                const Icon(Icons.add, color: AppColors.textSecondary, size: 16),
            label: const Text("Add Set",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)))
      ]),
    );
  }

  void _handleFinishWorkout(
      BuildContext context, WidgetRef ref, ActiveWorkoutNotifier notifier) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text("Finish Session",
                  style: TextStyle(color: Colors.white)),
              content: const Text("Are you ready to log this workout?",
                  style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Keep Training")),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent),
                    onPressed: () {
                      ref
                          .read(trackerProvider.notifier)
                          .saveWorkout(ref.read(activeWorkoutProvider));
                      notifier.endWorkout();
                      Navigator.pop(context);
                      context.go('/dashboard');
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
  final int index;
  final ActiveWorkoutNotifier notifier;
  final LogMode logMode;

  const _SetRow({
    super.key,
    required this.liveExId,
    required this.setItem,
    required this.index,
    required this.notifier,
    required this.logMode,
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
    if (oldWidget.setItem.weight != widget.setItem.weight &&
        weightCtrl.text != widget.setItem.weight) {
      weightCtrl.text = widget.setItem.weight;
    }
    if (oldWidget.setItem.reps != widget.setItem.reps &&
        repsCtrl.text != widget.setItem.reps) {
      repsCtrl.text = widget.setItem.reps;
    }
  }

  @override
  void dispose() {
    weightCtrl.dispose();
    repsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.setItem.isCompleted;
    final bool isTimeBased = widget.logMode == LogMode.timeAndReps ||
        widget.logMode == LogMode.timeAndDistance;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          color: isDone ? AppColors.accent.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDone
                  ? AppColors.accent.withOpacity(0.3)
                  : Colors.transparent)),
      child: Row(children: [
        SizedBox(
            width: 30,
            child: Text("${widget.index + 1}",
                style: TextStyle(
                    color: isDone ? AppColors.accent : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16))),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                    controller: weightCtrl,
                    keyboardType:
                        isTimeBased ? TextInputType.text : TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isDone ? AppColors.accent : Colors.white,
                        fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                        hintText: isTimeBased ? "00:00" : "0",
                        hintStyle: const TextStyle(
                            color: Colors.white24, fontSize: 12),
                        filled: true,
                        fillColor: isDone ? Colors.transparent : Colors.black12,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8)),
                    enabled: !isDone,
                    onChanged: (val) => widget.notifier.updateSet(
                        widget.liveExId, widget.setItem.id, 'weight', val)))),
        if (widget.logMode != LogMode.repsOnly)
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                      controller: repsCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: isDone ? AppColors.accent : Colors.white,
                          fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                          hintText: "0",
                          hintStyle: const TextStyle(
                              color: Colors.white24, fontSize: 12),
                          filled: true,
                          fillColor:
                              isDone ? Colors.transparent : Colors.black12,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8)),
                      enabled: !isDone,
                      onChanged: (val) => widget.notifier.updateSet(
                          widget.liveExId, widget.setItem.id, 'reps', val)))),
        SizedBox(
            width: 40,
            child: IconButton(
                icon: Icon(
                    isDone ? Icons.check_circle : Icons.check_circle_outline,
                    color: isDone ? AppColors.accent : AppColors.textSecondary),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  widget.notifier
                      .toggleSetComplete(widget.liveExId, widget.setItem.id);
                })),
      ]),
    );
  }
}
