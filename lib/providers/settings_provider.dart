import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FitnessGoal {
  weightLoss,
  muscleGain,
  strength,
  endurance,
  generalFitness,
  toning,
}

enum ExperienceLevel {
  beginner,
  intermediate,
  advanced,
}

class UserProfile {
  final String name;
  final int age;
  final double height;
  final double weight;
  final FitnessGoal goal;
  final ExperienceLevel experienceLevel;
  final int workoutsPerWeek;

  UserProfile({
    this.name = '',
    this.age = 25,
    this.height = 170,
    this.weight = 70,
    this.goal = FitnessGoal.generalFitness,
    this.experienceLevel = ExperienceLevel.beginner,
    this.workoutsPerWeek = 3,
  });

  UserProfile copyWith({
    String? name,
    int? age,
    double? height,
    double? weight,
    FitnessGoal? goal,
    ExperienceLevel? experienceLevel,
    int? workoutsPerWeek,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      goal: goal ?? this.goal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      workoutsPerWeek: workoutsPerWeek ?? this.workoutsPerWeek,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age.toString(),
        'height': height.toString(),
        'weight': weight.toString(),
        'goal': goal.name,
        'experienceLevel': experienceLevel.name,
        'workoutsPerWeek': workoutsPerWeek.toString(),
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        name: map['name'] ?? '',
        age: int.tryParse(map['age'] ?? '25') ?? 25,
        height: double.tryParse(map['height'] ?? '170') ?? 170,
        weight: double.tryParse(map['weight'] ?? '70') ?? 70,
        goal: FitnessGoal.values.firstWhere(
          (g) => g.name == map['goal'],
          orElse: () => FitnessGoal.generalFitness,
        ),
        experienceLevel: ExperienceLevel.values.firstWhere(
          (e) => e.name == map['experienceLevel'],
          orElse: () => ExperienceLevel.beginner,
        ),
        workoutsPerWeek: int.tryParse(map['workoutsPerWeek'] ?? '3') ?? 3,
      );

  String get goalLabel {
    switch (goal) {
      case FitnessGoal.weightLoss:
        return 'Weight Loss';
      case FitnessGoal.muscleGain:
        return 'Muscle Gain';
      case FitnessGoal.strength:
        return 'Strength';
      case FitnessGoal.endurance:
        return 'Endurance';
      case FitnessGoal.generalFitness:
        return 'General Fitness';
      case FitnessGoal.toning:
        return 'Toning';
    }
  }

  String get experienceLabel {
    switch (experienceLevel) {
      case ExperienceLevel.beginner:
        return 'Beginner';
      case ExperienceLevel.intermediate:
        return 'Intermediate';
      case ExperienceLevel.advanced:
        return 'Advanced';
    }
  }

  String get bmi {
    final heightInMeters = height / 100;
    final bmiValue = weight / (heightInMeters * heightInMeters);
    return bmiValue.toStringAsFixed(1);
  }

  String get bmiCategory {
    final bmiValue = double.tryParse(bmi) ?? 0;
    if (bmiValue < 18.5) return 'Underweight';
    if (bmiValue < 25) return 'Normal';
    if (bmiValue < 30) return 'Overweight';
    return 'Obese';
  }
}

class SettingsState {
  final String userUnit;
  final int defaultRestTime;
  final List<String> userEquipment;
  final bool useMetricSystem;
  final UserProfile profile;

  SettingsState({
    required this.userUnit,
    required this.defaultRestTime,
    this.userEquipment = const [
      'dumbbells',
      'barbell',
      'bodyweight',
      'machines',
      'cables'
    ],
    this.useMetricSystem = true,
    UserProfile? profile,
  }) : profile = profile ?? UserProfile();

  SettingsState copyWith({
    String? userUnit,
    int? defaultRestTime,
    List<String>? userEquipment,
    bool? useMetricSystem,
    UserProfile? profile,
  }) {
    return SettingsState(
      userUnit: userUnit ?? this.userUnit,
      defaultRestTime: defaultRestTime ?? this.defaultRestTime,
      userEquipment: userEquipment ?? this.userEquipment,
      useMetricSystem: useMetricSystem ?? this.useMetricSystem,
      profile: profile ?? this.profile,
    );
  }

  String get weightUnit => userUnit;
  String get sizeUnit => useMetricSystem ? 'cm' : 'in';
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _unitKey = 'userUnit';
  static const String _restKey = 'defaultRestTime';
  static const String _equipmentKey = 'user_equipment';
  static const String _metricKey = 'use_metric';
  static const String _profileKey = 'user_profile';

  @override
  SettingsState build() {
    _loadSettings();
    return SettingsState(
      userUnit: 'kg',
      defaultRestTime: 90,
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load profile
    UserProfile profile = UserProfile();
    final profileStr = prefs.getString(_profileKey);
    if (profileStr != null && profileStr.isNotEmpty) {
      try {
        final parts = profileStr.split('&');
        final map = <String, String>{};
        for (final part in parts) {
          final kv = part.split('=');
          if (kv.length == 2) {
            map[kv[0]] = Uri.decodeComponent(kv[1]);
          }
        }
        profile = UserProfile.fromMap(map);
      } catch (e) {
        profile = UserProfile();
      }
    }

    state = SettingsState(
      userUnit: prefs.getString(_unitKey) ?? 'kg',
      defaultRestTime: prefs.getInt(_restKey) ?? 90,
      userEquipment: prefs.getStringList(_equipmentKey) ??
          ['dumbbells', 'barbell', 'bodyweight', 'machines', 'cables'],
      useMetricSystem: prefs.getBool(_metricKey) ?? true,
      profile: profile,
    );
  }

  Future<void> setUnit(String unit) async {
    state = state.copyWith(userUnit: unit);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_unitKey, unit);
  }

  Future<void> setDefaultRestTime(int seconds) async {
    state = state.copyWith(defaultRestTime: seconds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_restKey, seconds);
  }

  Future<void> setMetricSystem(bool useMetric) async {
    state = state.copyWith(
      useMetricSystem: useMetric,
      userUnit: useMetric ? 'kg' : 'lbs',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_metricKey, useMetric);
    await prefs.setString(_unitKey, useMetric ? 'kg' : 'lbs');
  }

  Future<void> updateProfile(UserProfile profile) async {
    state = state.copyWith(profile: profile);
    final prefs = await SharedPreferences.getInstance();
    final profileStr = profile.toMap().entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    await prefs.setString(_profileKey, profileStr);
  }

  Future<void> addEquipment(String equipment) async {
    if (!state.userEquipment.contains(equipment)) {
      final updated = [...state.userEquipment, equipment];
      state = state.copyWith(userEquipment: updated);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_equipmentKey, updated);
    }
  }

  Future<void> removeEquipment(String equipment) async {
    final updated = state.userEquipment.where((e) => e != equipment).toList();
    state = state.copyWith(userEquipment: updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_equipmentKey, updated);
  }

  Future<void> toggleEquipment(String equipment) async {
    if (state.userEquipment.contains(equipment)) {
      await removeEquipment(equipment);
    } else {
      await addEquipment(equipment);
    }
  }

  Future<void> resetToDefaults() async {
    state = SettingsState(
      userUnit: 'kg',
      defaultRestTime: 90,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_unitKey, 'kg');
    await prefs.setInt(_restKey, 90);
    await prefs.setStringList(_equipmentKey,
        ['dumbbells', 'barbell', 'bodyweight', 'machines', 'cables']);
    await prefs.setBool(_metricKey, true);
    await prefs.remove(_profileKey);
  }

  bool get hasFullGym =>
      state.userEquipment.contains('barbell') &&
      state.userEquipment.contains('machines');

  bool get isHomeWorkout => state.userEquipment.every(
      (eq) => ['bodyweight', 'dumbbells', 'bands'].contains(eq.toLowerCase()));
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});