import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsModel>(
  (ref) => SettingsNotifier(),
);

// 최초 실행 여부 확인
final isFirstRunProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('is_first_run') ?? true;
});

class SettingsNotifier extends StateNotifier<SettingsModel> {
  SettingsNotifier() : super(const SettingsModel()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsModel(
      pm25Threshold: prefs.getDouble('pm25Threshold') ?? 35,
      tempMin: prefs.getDouble('tempMin') ?? 5,
      tempMax: prefs.getDouble('tempMax') ?? 28,
      rainThreshold: prefs.getDouble('rainThreshold') ?? 30,
    );
  }

  Future<void> update(SettingsModel newSettings) async {
    state = newSettings;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in newSettings.toMap().entries) {
      await prefs.setDouble(entry.key, entry.value);
    }
  }

  Future<void> completeFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_run', false);
  }
}
