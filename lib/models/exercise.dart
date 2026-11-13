class Exercise {
  final String id;
  final String name;
  final String equipment;
  final String level;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String category;
  final List<String> images;
  final List<String> instructions;

  Exercise({
    required this.id,
    required this.name,
    required this.equipment,
    required this.level,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.category,
    required this.images,
    required this.instructions,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      equipment: json['equipment'] ?? 'body only',
      level: json['level'] ?? 'beginner',
      primaryMuscles: List<String>.from(json['primaryMuscles'] ?? []),
      secondaryMuscles: List<String>.from(json['secondaryMuscles'] ?? []),
      category: json['category'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      instructions: List<String>.from(json['instructions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'equipment': equipment,
      'level': level,
      'primaryMuscles': primaryMuscles,
      'secondaryMuscles': secondaryMuscles,
      'category': category,
      'images': images,
      'instructions': instructions,
    };
  }
}
