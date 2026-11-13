import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/main_layout.dart';
import '../screens/dashboard_screen.dart';
import '../screens/library_screen.dart';
import '../screens/programs_hub_screen.dart';
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
import '../screens/workout_summary_screen.dart';
import '../screens/onboarding_screen.dart';

/// Overridden in main() once SharedPreferences has been read.
final needsOnboardingProvider = Provider<bool>((ref) => false);

final goRouterProvider = Provider<GoRouter>((ref) {
  final needsOnboarding = ref.read(needsOnboardingProvider);

  return GoRouter(
    initialLocation: needsOnboarding ? '/welcome' : '/dashboard',
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Workout routes
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

      // Shown after finishing; top-level so "back" can't return to the
      // (now ended) live session screen.
      GoRoute(
        path: '/summary',
        builder: (context, state) => const WorkoutSummaryScreen(),
      ),

      // Settings is opened from the profile button on the dashboard.
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // Exercise details reachable from full-screen routes outside the tab
      // shell (live workout, picker) without pushing a shell branch route.
      GoRoute(
        path: '/exercise/:id',
        builder: (context, state) => ExerciseDetailsScreen(
          exerciseId: state.pathParameters['id']!,
        ),
      ),

      // Exercise picker that only returns the chosen id (used by the program
      // builder) - it must NOT add anything to a running workout.
      GoRoute(
        path: '/pick-exercise',
        builder: (context, state) =>
            const WorkoutExerciseSelectionScreen(pickOnly: true),
      ),

      // Main shell with bottom navigation (4 tabs)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainLayout(navigationShell: navigationShell),
        branches: [
          // 0 - Home
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

          // 2 - Programs (mine + discover)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/programs',
              builder: (context, state) => ProgramsHubScreen(
                initialTab:
                    state.uri.queryParameters['tab'] == 'discover' ? 1 : 0,
              ),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) => ProgramCreatorScreen(
                    editProgramId: state.uri.queryParameters['id'],
                    initialExerciseId:
                        state.uri.queryParameters['initialExerciseId'],
                  ),
                ),
                GoRoute(
                  path: 'discover/:id',
                  builder: (context, state) => WorkoutPreviewScreen(
                    programId: state.pathParameters['id']!,
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

          // 3 - Progress
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
        ],
      ),

      // Old links -> new locations.
      GoRoute(path: '/discover', redirect: (_, __) => '/programs?tab=discover'),
      GoRoute(
        path: '/discover/program/:id',
        redirect: (_, state) =>
            '/programs/discover/${state.pathParameters['id']}',
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
