import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/program_provider.dart';
import '../services/image_cache_service.dart';
import '../models/program.dart';
import '../theme/app_theme.dart';
import '../widgets/workout_launcher.dart';

class ProgramsScreen extends ConsumerStatefulWidget {
  const ProgramsScreen({super.key});

  @override
  ConsumerState<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends ConsumerState<ProgramsScreen> {
  @override
  Widget build(BuildContext context) {
    final programState = ref.watch(programProvider);
    final customPrograms = programState.customPrograms;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, customPrograms.length, isSmallScreen),
            Expanded(
              child: programState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : customPrograms.isEmpty
                      ? _buildEmptyState(context, isSmallScreen)
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 16 : 24,
                          ),
                          itemCount: customPrograms.length,
                          itemBuilder: (context, index) {
                            final program = customPrograms[index];
                            return _buildProgramTile(
                                context, program, isSmallScreen);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, int programCount, bool isSmallScreen) {
    final fontSize = isSmallScreen ? 22.0 : 28.0;
    final iconSize = isSmallScreen ? 24.0 : 28.0;

    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "MY PROGRAMS",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.explore_outlined,
                      color: AppColors.accent,
                      size: iconSize,
                    ),
                    onPressed: () => context.go('/programs?tab=discover'),
                    tooltip: 'Discover Programs',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: AppColors.accent,
                      size: iconSize,
                    ),
                    onPressed: () => context.push('/programs/create'),
                    tooltip: 'Create Program',
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            "$programCount ${programCount == 1 ? 'program' : 'programs'} saved",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: isSmallScreen ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramTile(
      BuildContext context, Program program, bool isSmallScreen) {
    final programState = ref.read(programProvider);
    final isActive = programState.activeProgramId == program.id;
    final tilePadding = isSmallScreen ? 12.0 : 16.0;
    final imageSize = isSmallScreen ? 60.0 : 70.0;
    final borderRadius = isSmallScreen ? 16.0 : 20.0;
    final titleSize = isSmallScreen ? 14.0 : 16.0;
    final subtitleSize = isSmallScreen ? 10.0 : 12.0;

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/programs/${program.id}'),
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: EdgeInsets.all(tilePadding),
            child: Row(
              children: [
                // Program Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                  child: SizedBox(
                    width: imageSize,
                    height: imageSize,
                    child: ImageCacheService.cachedImage(
                      program.displayImage,
                      fit: BoxFit.cover,
                      placeholder: ImageCacheService.shimmerPlaceholder(
                        borderRadius: isSmallScreen ? 10 : 12,
                      ),
                      errorWidget: Container(
                        color: AppColors.background,
                        child: Icon(
                          Icons.fitness_center,
                          color: Colors.white24,
                          size: isSmallScreen ? 24 : 30,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),

                // Program Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              program.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleSize,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isActive)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 6 : 8,
                                vertical: isSmallScreen ? 1 : 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                    isSmallScreen ? 6 : 8),
                              ),
                              child: Text(
                                "ACTIVE",
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: isSmallScreen ? 7 : 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 3 : 4),
                      Text(
                        "${program.totalWorkouts} workouts • ${program.difficultyLabel}",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: subtitleSize,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 3 : 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 5 : 6,
                              vertical: isSmallScreen ? 1 : 2,
                            ),
                            decoration: BoxDecoration(
                              color: program.difficultyColor.withValues(alpha: 0.2),
                              borderRadius:
                                  BorderRadius.circular(isSmallScreen ? 5 : 6),
                            ),
                            child: Text(
                              program.difficultyLabel,
                              style: TextStyle(
                                color: program.difficultyColor,
                                fontSize: isSmallScreen ? 8 : 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (program.isImported)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 5 : 6,
                                vertical: isSmallScreen ? 1 : 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                    isSmallScreen ? 5 : 6),
                              ),
                              child: Text(
                                "IMPORTED",
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: isSmallScreen ? 7 : 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Menu Button
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.white38,
                    size: isSmallScreen ? 20 : 24,
                  ),
                  onPressed: () => _showProgramOptions(context, program),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isSmallScreen) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isSmallScreen ? 100 : 120,
            height: isSmallScreen ? 100 : 120,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(
              Icons.folder_open,
              size: isSmallScreen ? 40 : 48,
              color: Colors.white24,
            ),
          ),
          SizedBox(height: isSmallScreen ? 20 : 24),
          Text(
            "No Programs Yet",
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            "Create your own or discover popular workouts",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: isSmallScreen ? 12 : 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isSmallScreen ? 24 : 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.push('/programs/create'),
                icon: Icon(Icons.add, size: isSmallScreen ? 16 : 18),
                label: Text(
                  "CREATE",
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20 : 24,
                    vertical: isSmallScreen ? 12 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(isSmallScreen ? 12 : 16),
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              OutlinedButton.icon(
                onPressed: () => context.go('/programs?tab=discover'),
                icon: Icon(Icons.explore, size: isSmallScreen ? 16 : 18),
                label: Text(
                  "DISCOVER",
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20 : 24,
                    vertical: isSmallScreen ? 12 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(isSmallScreen ? 12 : 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showProgramOptions(BuildContext context, Program program) {
    final programState = ref.read(programProvider);
    final isActive = programState.activeProgramId == program.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                program.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.white70),
                title: const Text("View Details",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/programs/${program.id}');
                },
              ),
              if (program.isCustom) ...[
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white70),
                  title: const Text("Edit Program",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/programs/create?id=${program.id}');
                  },
                ),
              ],
              ListTile(
                leading: Icon(
                  isActive ? Icons.check_circle : Icons.play_circle_outline,
                  color: isActive ? AppColors.accent : Colors.white70,
                ),
                title: Text(
                  isActive ? "Active Program" : "Set as Active",
                  style: TextStyle(
                    color: isActive ? AppColors.accent : Colors.white,
                  ),
                ),
                onTap: isActive
                    ? null
                    : () {
                        ref
                            .read(programProvider.notifier)
                            .setActiveProgram(program.id);
                        Navigator.pop(context);
                      },
              ),
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Colors.white70),
                title: const Text("Start Workout",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _startProgram(context, program);
                },
              ),
              if (program.isCustom) ...[
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text("Delete Program",
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(context, program);
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _startProgram(BuildContext context, Program program) {
    final programNotifier = ref.read(programProvider.notifier);

    if (program.routines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This program has no routines'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Continue where the user left off if this is already the active program.
    final ps = ref.read(programProvider);
    final isActive = ps.activeProgramId == program.id;
    final idx = isActive ? ps.currentRoutineIndex % program.routines.length : 0;
    final routine = program.routines[idx];

    launchWorkout(
      context,
      ref,
      routine: routine,
      onStarted: () {
        if (!isActive) programNotifier.setActiveProgram(program.id);
        programNotifier.setCurrentRoutineIndex(idx + 1);
      },
    );
  }

  void _confirmDelete(BuildContext context, Program program) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Delete Program?",
            style: TextStyle(color: Colors.white)),
        content: Text(
          "Are you sure you want to delete '${program.name}'?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              ref.read(programProvider.notifier).deleteProgram(program.id);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
