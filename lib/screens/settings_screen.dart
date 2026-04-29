import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/tracker_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Text(
                  "SETTINGS",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 22 : 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 24,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // PROFILE SECTION
                  _buildSectionHeader("PROFILE"),
                  _buildProfileCard(context, ref, settings.profile, isSmallScreen),
                  const SizedBox(height: 32),

                  // PREFERENCES SECTION
                  _buildSectionHeader("PREFERENCES"),
                  _buildUnitToggle(
                    title: "Weight Unit",
                    value: settings.userUnit.toUpperCase(),
                    options: ["KG", "LBS"],
                    onChanged: (val) => notifier.setUnit(val.toLowerCase()),
                    isSmallScreen: isSmallScreen,
                  ),
                  const SizedBox(height: 12),
                  _buildUnitToggle(
                    title: "Measurement System",
                    value: settings.useMetricSystem ? "METRIC" : "IMPERIAL",
                    options: ["METRIC", "IMPERIAL"],
                    onChanged: (val) => notifier.setMetricSystem(val == "METRIC"),
                    isSmallScreen: isSmallScreen,
                  ),
                  const SizedBox(height: 32),

                  // WORKOUT SECTION
                  _buildSectionHeader("WORKOUT"),
                  _buildRestTimerSetting(ref, isSmallScreen),
                  const SizedBox(height: 32),

                  // EQUIPMENT SECTION
                  _buildSectionHeader("MY EQUIPMENT"),
                  _buildEquipmentSection(ref, settings, isSmallScreen),
                  const SizedBox(height: 32),

                  // APP SECTION
                  _buildSectionHeader("APP"),
                  _buildSettingCard(
                    icon: Icons.info_outline,
                    title: "About GymGenius",
                    subtitle: "Version 1.0.0",
                    trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                    onTap: () => _showAboutDialog(context),
                    isSmallScreen: isSmallScreen,
                  ),
                  const SizedBox(height: 32),

                  // DATA MANAGEMENT
                  _buildSectionHeader("DATA MANAGEMENT"),
                  _buildSettingCard(
                    icon: Icons.delete_outline,
                    title: "Clear All Data",
                    titleColor: Colors.redAccent,
                    subtitle: "Workouts, metrics, programs",
                    onTap: () => _showDeleteDialog(context, ref),
                    isSmallScreen: isSmallScreen,
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, WidgetRef ref, UserProfile profile, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // Avatar and name
          Row(
            children: [
              Container(
                height: isSmallScreen ? 56 : 64,
                width: isSmallScreen ? 56 : 64,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name.isNotEmpty ? profile.name : "Athlete",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "${profile.experienceLabel} • ${profile.goalLabel}",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: isSmallScreen ? 11 : 13,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "${profile.workoutsPerWeek}x per week",
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: isSmallScreen ? 10 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: AppColors.accent,
                  size: isSmallScreen ? 20 : 24,
                ),
                onPressed: () => _showEditProfileDialog(context, ref, profile),
              ),
            ],
          ),
          if (profile.name.isNotEmpty) ...[
            SizedBox(height: isSmallScreen ? 16 : 20),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip('Age', '${profile.age}', isSmallScreen),
                _buildStatChip('Height', '${profile.height} cm', isSmallScreen),
                _buildStatChip('Weight', '${profile.weight} kg', isSmallScreen),
                _buildStatChip('BMI', profile.bmi, isSmallScreen,
                    color: _getBMIColor(profile.bmiCategory)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, bool isSmallScreen, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: isSmallScreen ? 9 : 10,
          ),
        ),
      ],
    );
  }

  Color _getBMIColor(String category) {
    switch (category) {
      case 'Underweight':
        return Colors.amber;
      case 'Normal':
        return Colors.green;
      case 'Overweight':
        return Colors.orange;
      case 'Obese':
        return Colors.red;
      default:
        return Colors.white;
    }
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, UserProfile profile) {
    final nameController = TextEditingController(text: profile.name);
    final ageController = TextEditingController(text: profile.age.toString());
    final heightController = TextEditingController(text: profile.height.toString());
    final weightController = TextEditingController(text: profile.weight.toString());
    
    FitnessGoal selectedGoal = profile.goal;
    ExperienceLevel selectedLevel = profile.experienceLevel;
    int workoutsPerWeek = profile.workoutsPerWeek;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Edit Profile",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Name'),
                ),
                const SizedBox(height: 12),
                
                // Age
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Age'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Workouts per week
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Per Week',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          const SizedBox(height: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [1, 2, 3, 4, 5, 6, 7].map((n) {
                                final selected = workoutsPerWeek == n;
                                return GestureDetector(
                                  onTap: () => setDialogState(() => workoutsPerWeek = n),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: selected ? AppColors.accent : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('$n',
                                        style: TextStyle(
                                            color: selected ? Colors.black : Colors.white54,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Height & Weight
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: heightController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Height (cm)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Weight (kg)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Goal
                const Text("Fitness Goal",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FitnessGoal.values.map((goal) {
                    final isSelected = selectedGoal == goal;
                    return ChoiceChip(
                      label: Text(goal.name == 'weightLoss' ? 'Weight Loss' :
                          goal.name == 'muscleGain' ? 'Muscle Gain' :
                          goal.name == 'generalFitness' ? 'General Fitness' :
                          goal.name[0].toUpperCase() + goal.name.substring(1),
                          style: TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onSelected: (_) => setDialogState(() => selectedGoal = goal),
                      backgroundColor: AppColors.background,
                      selectedColor: AppColors.accent,
                      labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontSize: 11),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                
                // Experience
                const Text("Experience Level",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 8),
                Row(
                  children: ExperienceLevel.values.map((level) {
                    final isSelected = selectedLevel == level;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(level.name[0].toUpperCase() + level.name.substring(1),
                              style: TextStyle(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (_) => setDialogState(() => selectedLevel = level),
                          backgroundColor: AppColors.background,
                          selectedColor: AppColors.accent,
                          labelStyle: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontSize: 11),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final updatedProfile = UserProfile(
                  name: nameController.text.trim(),
                  age: int.tryParse(ageController.text) ?? profile.age,
                  height: double.tryParse(heightController.text) ?? profile.height,
                  weight: double.tryParse(weightController.text) ?? profile.weight,
                  goal: selectedGoal,
                  experienceLevel: selectedLevel,
                  workoutsPerWeek: workoutsPerWeek,
                );
                ref.read(settingsProvider.notifier).updateProfile(updatedProfile);
                Navigator.pop(context);
              },
              child: const Text("SAVE",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildEquipmentSection(WidgetRef ref, SettingsState settings, bool isSmallScreen) {
    final availableEquipment = [
      'Dumbbells',
      'Barbell',
      'Bodyweight',
      'Machines',
      'Cables',
      'Kettlebells',
      'Bands',
      'Pull-up Bar',
    ];

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: availableEquipment.map((eq) {
          final isSelected = settings.userEquipment.any(
              (e) => e.toLowerCase() == eq.toLowerCase());
          return FilterChip(
            label: Text(eq, style: TextStyle(fontSize: isSmallScreen ? 11 : 12)),
            selected: isSelected,
            onSelected: (_) => ref.read(settingsProvider.notifier).toggleEquipment(eq.toLowerCase()),
            backgroundColor: AppColors.background,
            selectedColor: AppColors.accent.withOpacity(0.2),
            checkmarkColor: AppColors.accent,
            labelStyle: TextStyle(
              color: isSelected ? AppColors.accent : Colors.white70,
              fontSize: isSmallScreen ? 11 : 12,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ... (rest of the methods: _buildSectionHeader, _buildSettingCard, _buildUnitToggle, _buildRestTimerSetting, _showAboutDialog, _showDeleteDialog remain the same as before)
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color titleColor = Colors.white,
    VoidCallback? onTap,
    bool isSmallScreen = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              height: isSmallScreen ? 36 : 40,
              width: isSmallScreen ? 36 : 40,
              decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12)),
              child: Icon(icon, color: titleColor.withOpacity(0.7), size: isSmallScreen ? 18 : 20),
            ),
            SizedBox(width: isSmallScreen ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 14 : 16)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildUnitToggle({
    required String title,
    required String value,
    required List<String> options,
    required Function(String) onChanged,
    bool isSmallScreen = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 14 : 16)),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: options.map((opt) {
                bool isSelected = value == opt;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onChanged(opt);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      opt,
                      style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 11 : 12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestTimerSetting(WidgetRef ref, bool isSmallScreen) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Rest Timer",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 14 : 16)),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [60, 90, 120].map((seconds) {
                bool isSelected = settings.defaultRestTime == seconds;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    notifier.setDefaultRestTime(seconds);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${seconds}s",
                      style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 11 : 12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("About GymGenius",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Version 1.0.0",
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
                "Your ultimate gym companion. Track workouts, build programs, and crush your fitness goals.",
                style: TextStyle(color: Colors.white70)),
            SizedBox(height: 16),
            Text("Made with 💪 and Flutter",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("CLOSE", style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Clear All Data?",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            "This will permanently delete your workout history, metrics, and custom programs. This cannot be undone.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL",
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await ref.read(trackerProvider.notifier).clearAllData();
              Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("All data cleared."),
                    backgroundColor: AppColors.accent,
                  ),
                );
              }
            },
            child: const Text("DELETE EVERYTHING",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}