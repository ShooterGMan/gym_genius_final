import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/data_actions.dart';

const String onboardingDoneKey = 'onboarding_done';

/// First-launch setup: name, units, goal, experience and weekly target.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  final _nameCtrl = TextEditingController();
  int _step = 0;

  bool _metric = true;
  FitnessGoal _goal = FitnessGoal.generalFitness;
  ExperienceLevel _level = ExperienceLevel.beginner;
  int _perWeek = 3;
  bool _saving = false;

  static const _steps = 3;

  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step < _steps - 1) {
      _page.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final settings = ref.read(settingsProvider.notifier);
    final profile = ref.read(settingsProvider).profile.copyWith(
          name: _nameCtrl.text.trim(),
          goal: _goal,
          experienceLevel: _level,
          workoutsPerWeek: _perWeek,
        );
    await settings.setMetricSystem(_metric);
    await settings.updateProfile(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingDoneKey, true);
    if (mounted) context.go('/dashboard');
  }

  Future<void> _restore() async {
    final restored = await DataActions.restore(context, ref);
    if (restored && mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: List.generate(
                  _steps,
                  (i) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4,
                      margin: EdgeInsets.only(right: i == _steps - 1 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: i <= _step ? AppColors.accent : Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _welcomeStep(),
                  _goalStep(),
                  _scheduleStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => _page.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut),
                      child: const Text('Back',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _saving ? null : _next,
                      child: Text(
                        _step == _steps - 1 ? "LET'S GO" : 'NEXT',
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1),
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

  Widget _title(String kicker, String title) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kicker,
              style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.15)),
          const SizedBox(height: 28),
        ],
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 8),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onTap();
        },
        showCheckmark: false,
        selectedColor: AppColors.accent,
        backgroundColor: AppColors.surface,
        side: BorderSide(
            color: selected ? AppColors.accent : AppColors.border),
        labelStyle: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold),
      );

  Widget _welcomeStep() => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.bolt, color: AppColors.accent, size: 48),
          const SizedBox(height: 16),
          _title('WELCOME TO GYMGENIUS', 'Let’s set things up.\nTakes 20 seconds.'),
          _label('WHAT SHOULD WE CALL YOU?'),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _next(),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Your name (optional)',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          _label('UNITS'),
          Wrap(spacing: 8, children: [
            _chip('kg / cm', _metric, () => setState(() => _metric = true)),
            _chip('lbs / in', !_metric, () => setState(() => _metric = false)),
          ]),
          const SizedBox(height: 32),
          Center(
            child: TextButton.icon(
              onPressed: _restore,
              icon: const Icon(Icons.settings_backup_restore,
                  color: AppColors.textSecondary, size: 18),
              label: const Text('Moving from another phone? Restore a backup',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ],
      );

  Widget _goalStep() {
    const goals = {
      FitnessGoal.muscleGain: 'Build muscle',
      FitnessGoal.strength: 'Get stronger',
      FitnessGoal.weightLoss: 'Lose fat',
      FitnessGoal.endurance: 'Endurance',
      FitnessGoal.toning: 'Tone up',
      FitnessGoal.generalFitness: 'General fitness',
    };
    const levels = {
      ExperienceLevel.beginner: 'New to lifting',
      ExperienceLevel.intermediate: '1–3 years',
      ExperienceLevel.advanced: '3+ years',
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        _title('YOUR GOAL', 'What are you\ntraining for?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in goals.entries)
              _chip(e.value, _goal == e.key, () => setState(() => _goal = e.key)),
          ],
        ),
        const SizedBox(height: 24),
        _label('EXPERIENCE'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in levels.entries)
              _chip(e.value, _level == e.key,
                  () => setState(() => _level = e.key)),
          ],
        ),
      ],
    );
  }

  Widget _scheduleStep() => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          _title('YOUR WEEK', 'How many days a week\ncan you train?'),
          Center(
            child: Text('$_perWeek',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 72,
                    fontWeight: FontWeight.w900)),
          ),
          Center(
            child: Text(_perWeek == 1 ? 'day per week' : 'days per week',
                style: const TextStyle(color: Colors.white70)),
          ),
          Slider(
            value: _perWeek.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            activeColor: AppColors.accent,
            inactiveColor: Colors.white12,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _perWeek = v.round());
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _perWeek <= 3
                  ? 'Tip: a full-body program works great at $_perWeek days. Find one under Programs → Discover.'
                  : _perWeek == 4
                      ? 'Tip: an upper/lower split fits 4 days nicely. Find one under Programs → Discover.'
                      : 'Tip: push/pull/legs suits $_perWeek days. Find one under Programs → Discover.',
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      );
}
