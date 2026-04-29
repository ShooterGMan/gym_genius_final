import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/main_layout.dart';
import '../screens/dashboard_screen.dart';
import '../screens/library_screen.dart';
import '../screens/discover_screen.dart';
import '../screens/programs_screen.dart';
import '../screens/tracker_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/exercise_list_screen.dart';
import '../screens/exercise_details_screen.dart';
import '../screens/program_details_screen.dart';
import '../screens/workout_preview_screen.dart';
import '../screens/active_workout_screen.dart';
import '../screens/workout_exercise_selection_screen.dart';
import '../screens/workout_history_details_screen.dart';
import '../screens/program_creator_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      // Workout routes (outside shell - full screen)
      GoRoute(
        path: '/workout',
        builder: (context, state) => const ActiveWorkoutScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) => const WorkoutExerciseSelectionScreen(),
          ),
        ],
      ),

      // Main shell with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainLayout(navigationShell: navigationShell),
        branches: [
          // 0 - Dashboard
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),

          // 1 - Library
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
              routes: [
                GoRoute(
                  path: 'exercise/:id',
                  builder: (context, state) => ExerciseDetailsScreen(
                    exerciseId: state.pathParameters['id']!,
                  ),
                ),
                GoRoute(
                  path: ':category',
                  builder: (context, state) => ExerciseListScreen(
                    category: state.pathParameters['category']!,
                  ),
                ),
              ],
            ),
          ]),

          // 2 - Discover (Pre-built programs)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/discover',
              builder: (context, state) => const DiscoverScreen(),
              routes: [
                // IMPORTANT: This route must match what discover_screen.dart pushes
                GoRoute(
                  path: 'program/:id',
                  builder: (context, state) {
                    final programId = state.pathParameters['id']!;
                    return WorkoutPreviewScreen(programId: programId);
                  },
                ),
              ],
            ),
          ]),

          // 3 - Programs (Custom + Saved)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/programs',
              builder: (context, state) => const ProgramsScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) => ProgramCreatorScreen(
                    editProgramId: state.uri.queryParameters['id'],
                    initialExerciseId: state.uri.queryParameters['initialExerciseId'],
                  ),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => ProgramDetailsScreen(
                    programId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ]),

          // 4 - Tracker
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tracker',
              builder: (context, state) => const TrackerScreen(),
              routes: [
                GoRoute(
                  path: 'history/:id',
                  builder: (context, state) => WorkoutHistoryDetailsScreen(
                    workoutId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ]),

          // 5 - Settings
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Page Not Found',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCFF00),
                foregroundColor: Colors.black,
              ),
              child: const Text('GO TO DASHBOARD'),
            ),
          ],
        ),
      ),
    ),
  );
});