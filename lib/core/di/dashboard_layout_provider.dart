import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gösterilecek dashboard widget ID'leri
/// Tüm ID'ler varsayılan olarak görünür
const List<String> kAllDashboardItems = [
  'stat_hayvan',
  'stat_asi',
  'stat_yakit',
  'stat_stok',
  'quick_actions',
  'module_hayvan',
  'module_arac',
  'module_yapi',
  'module_stok',
  'module_raporlar',
];

const Map<String, String> kDashboardItemLabels = {
  'stat_hayvan': 'Toplam Hayvan',
  'stat_asi': 'Yaklaşan Aşı',
  'stat_yakit': 'Aylık Yakıt',
  'stat_stok': 'Düşük Stok',
  'quick_actions': 'Hızlı İşlemler',
  'module_hayvan': 'Hayvan Yönetimi',
  'module_arac': 'Araç & Makineler',
  'module_yapi': 'Yapılar & Enerji',
  'module_stok': 'Stok Yönetimi',
  'module_raporlar': 'Raporlar',
};

class DashboardLayoutNotifier extends StateNotifier<Set<String>> {
  static const _prefsKey = 'dashboard_hidden_items';

  DashboardLayoutNotifier() : super(kAllDashboardItems.toSet()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList(_prefsKey) ?? [];
    state = kAllDashboardItems.where((id) => !hidden.contains(id)).toSet();
  }

  bool isVisible(String id) => state.contains(id);

  Future<void> toggle(String id) async {
    final newState = Set<String>.from(state);
    if (newState.contains(id)) {
      newState.remove(id);
    } else {
      newState.add(id);
    }
    state = newState;
    await _save(newState);
  }

  Future<void> _save(Set<String> visible) async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = kAllDashboardItems.where((id) => !visible.contains(id)).toList();
    await prefs.setStringList(_prefsKey, hidden);
  }

  Future<void> resetToDefault() async {
    state = kAllDashboardItems.toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<void> restoreFrom(Set<String> snapshot) async {
    state = snapshot;
    await _save(snapshot);
  }
}

final dashboardLayoutProvider =
    StateNotifierProvider<DashboardLayoutNotifier, Set<String>>(
  (_) => DashboardLayoutNotifier(),
);
