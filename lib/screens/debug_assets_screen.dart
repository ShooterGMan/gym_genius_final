import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugAssetsScreen extends StatefulWidget {
  const DebugAssetsScreen({super.key});

  @override
  State<DebugAssetsScreen> createState() => _DebugAssetsScreenState();
}

class _DebugAssetsScreenState extends State<DebugAssetsScreen> {
  final List<String> _testPaths = [
    // Category images
    'assets/workout_covers/categories/chest.jpg',
    'assets/workout_covers/categories/back.jpg',
    'assets/workout_covers/categories/legs.jpg',
    'assets/workout_covers/categories/shoulders.jpg',
    'assets/workout_covers/categories/arms.jpg',
    'assets/workout_covers/categories/core.jpg',
    'assets/workout_covers/categories/cardio.jpg',
    'assets/workout_covers/categories/full_body.jpg',
    'assets/workout_covers/categories/strength.jpg',
    'assets/workout_covers/categories/hypertrophy.jpg',
    'assets/workout_covers/categories/endurance.jpg',
    'assets/workout_covers/categories/weight_loss.jpg',
    'assets/workout_covers/categories/beginner.jpg',
    'assets/workout_covers/categories/intermediate.jpg',
    'assets/workout_covers/categories/advanced.jpg',
    'assets/workout_covers/categories/upper_lower.jpg',
    'assets/workout_covers/categories/ppl.jpg',
    'assets/workout_covers/categories/bro_split.jpg',

    // Workout images
    'assets/workout_covers/workouts/summer_shred.jpg',
    'assets/workout_covers/workouts/mass_builder.jpg',
    'assets/workout_covers/workouts/strength_foundation.jpg',
    'assets/workout_covers/workouts/glute_warrior.jpg',
    'assets/workout_covers/workouts/home_hero.jpg',
    'assets/workout_covers/workouts/athlete_power.jpg',
    'assets/workout_covers/workouts/quick_burn.jpg',

    // Alternative paths (without assets/)
    'workout_covers/categories/chest.jpg',
    'workout_covers/categories/back.jpg',
    'workout_covers/workouts/summer_shred.jpg',

    // Placeholder paths
    'assets/placeholders/chest.avif',
    'assets/placeholders/back.avif',
    'assets/placeholders/legs.avif',
    'assets/placeholders/full body.avif',

    // JSON files
    'assets/exercises.json',
    'assets/popular_workouts.json',
  ];

  final Map<String, bool> _results = {};
  bool _isChecking = false;

  Future<void> _checkAllAssets() async {
    setState(() {
      _isChecking = true;
      _results.clear();
    });

    for (final path in _testPaths) {
      try {
        await rootBundle.load(path);
        _results[path] = true;
      } catch (e) {
        _results[path] = false;
      }
    }

    setState(() {
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: const Text('Asset Debugger'),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isChecking ? null : _checkAllAssets,
              child: _isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('CHECK ALL ASSETS'),
            ),
          ),
          if (_results.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final path = _results.keys.elementAt(index);
                  final exists = _results[path]!;
                  return ListTile(
                    leading: Icon(
                      exists ? Icons.check_circle : Icons.error,
                      color: exists ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      path,
                      style: TextStyle(
                        color: exists ? Colors.white70 : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Text(
                      exists ? '✓ Found' : '✗ Not found',
                      style: TextStyle(
                        color: exists ? Colors.green : Colors.red,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
