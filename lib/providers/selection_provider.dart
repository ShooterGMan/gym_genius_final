import 'package:flutter_riverpod/flutter_riverpod.dart';

// This keeps track of which program/day we are currently "adding to"
final selectedDayProvider = StateProvider<Map<String, String>?>((ref) => null);
