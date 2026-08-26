import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final double dieselPricePerLiter;  // ₺/litre — motorin
  final double benzinPricePerLiter;  // ₺/litre — benzin
  final double milkPricePerLiter;    // ₺/litre
  final double electricityRate;      // ₺/kWh
  final String farmName;
  final String ownerName;

  const AppSettings({
    this.dieselPricePerLiter = 42.5,
    this.benzinPricePerLiter = 45.0,
    this.milkPricePerLiter = 18.0,
    this.electricityRate = 3.5,
    this.farmName = 'Çiftliğim',
    this.ownerName = '',
  });

  AppSettings copyWith({
    double? dieselPricePerLiter,
    double? benzinPricePerLiter,
    double? milkPricePerLiter,
    double? electricityRate,
    String? farmName,
    String? ownerName,
  }) =>
      AppSettings(
        dieselPricePerLiter: dieselPricePerLiter ?? this.dieselPricePerLiter,
        benzinPricePerLiter: benzinPricePerLiter ?? this.benzinPricePerLiter,
        milkPricePerLiter: milkPricePerLiter ?? this.milkPricePerLiter,
        electricityRate: electricityRate ?? this.electricityRate,
        farmName: farmName ?? this.farmName,
        ownerName: ownerName ?? this.ownerName,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const _dieselKey = 'diesel_price';
  static const _benzinKey = 'benzin_price';
  static const _milkKey = 'milk_price';
  static const _elecKey = 'electricity_rate';
  static const _farmNameKey = 'farm_name';
  static const _ownerNameKey = 'owner_name';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // Eski 'fuel_price' anahtarını motorin için fallback olarak kullan
    final legacyFuel = prefs.getDouble('fuel_price');
    state = AppSettings(
      dieselPricePerLiter: prefs.getDouble(_dieselKey) ?? legacyFuel ?? 42.5,
      benzinPricePerLiter: prefs.getDouble(_benzinKey) ?? 45.0,
      milkPricePerLiter: prefs.getDouble(_milkKey) ?? 18.0,
      electricityRate: prefs.getDouble(_elecKey) ?? 3.5,
      farmName: prefs.getString(_farmNameKey) ?? 'Çiftliğim',
      ownerName: prefs.getString(_ownerNameKey) ?? '',
    );
  }

  Future<void> update({
    double? dieselPricePerLiter,
    double? benzinPricePerLiter,
    double? milkPricePerLiter,
    double? electricityRate,
    String? farmName,
    String? ownerName,
  }) async {
    state = state.copyWith(
      dieselPricePerLiter: dieselPricePerLiter,
      benzinPricePerLiter: benzinPricePerLiter,
      milkPricePerLiter: milkPricePerLiter,
      electricityRate: electricityRate,
      farmName: farmName,
      ownerName: ownerName,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_dieselKey, state.dieselPricePerLiter);
    await prefs.setDouble(_benzinKey, state.benzinPricePerLiter);
    await prefs.setDouble(_milkKey, state.milkPricePerLiter);
    await prefs.setDouble(_elecKey, state.electricityRate);
    await prefs.setString(_farmNameKey, state.farmName);
    await prefs.setString(_ownerNameKey, state.ownerName);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);
