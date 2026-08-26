import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
export '../../features/auth/presentation/providers/auth_provider.dart';

// Shared Preferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main');
});

// Theme Mode
final themeModeProvider = StateProvider<bool>((ref) => false);
