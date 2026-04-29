import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesState {
  final List<String> exerciseIds;
  final bool isLoading;

  FavoritesState({
    this.exerciseIds = const [],
    this.isLoading = false,
  });

  FavoritesState copyWith({
    List<String>? exerciseIds,
    bool? isLoading,
  }) {
    return FavoritesState(
      exerciseIds: exerciseIds ?? this.exerciseIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FavoritesNotifier extends Notifier<FavoritesState> {
  static const String _storageKey = 'favorite_exercises_v1';

  @override
  FavoritesState build() {
    _loadFavorites();
    return FavoritesState();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_storageKey) ?? [];
    state = state.copyWith(exerciseIds: ids, isLoading: false);
  }

  Future<void> toggleFavorite(String exerciseId) async {
    final updatedIds = List<String>.from(state.exerciseIds);
    
    if (updatedIds.contains(exerciseId)) {
      updatedIds.remove(exerciseId);
    } else {
      updatedIds.insert(0, exerciseId); // Add to front for recency
    }

    state = state.copyWith(exerciseIds: updatedIds);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, updatedIds);
  }

  bool isFavorite(String exerciseId) {
    return state.exerciseIds.contains(exerciseId);
  }

  Future<void> clearAllFavorites() async {
    state = state.copyWith(exerciseIds: []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, FavoritesState>(() {
  return FavoritesNotifier();
});