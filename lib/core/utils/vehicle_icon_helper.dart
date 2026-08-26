import 'package:flutter/material.dart';

class VehicleIconHelper {
  /// Araç tipine göre ikon
  static IconData getTypeIcon(String vehicleType) {
    switch (vehicleType) {
      case 'Traktör': return Icons.agriculture_rounded;
      case 'Biçerdöver': return Icons.grass_rounded;
      case 'Kamyon': return Icons.local_shipping_rounded;
      case 'Araç': return Icons.directions_car_rounded;
      case 'Jeneratör': return Icons.electric_bolt_rounded;
      case 'İş Makinesi':
      case 'İş Makinası': return Icons.construction_rounded;
      case 'Sulama Pompası': return Icons.water_rounded;
      default: return Icons.directions_car_rounded;
    }
  }

  /// Model adına göre daha spesifik araç ikonu (binek araçlar için)
  static IconData getModelIcon(String vehicleType, String? model) {
    if (vehicleType != 'Araç' || model == null) {
      return getTypeIcon(vehicleType);
    }
    final m = model.toLowerCase();
    // Pickup / SUV
    if (_containsAny(m, ['navara','ranger','hilux','l200','amarok','d-max','triton','ridgeline','gladiator','frontier','tacoma','tundra','colorado','canyon','maverick','+130'])) {
      return Icons.fire_truck_rounded; // pickup
    }
    // Minivan / Van
    if (_containsAny(m, ['vito','transit','sprinter','connect','berlingo','partner','jumpy','expert','trafic','vivaro','transporter','caddy','doblo','scudo','kangoo','combo'])) {
      return Icons.airport_shuttle_rounded;
    }
    // SUV / Crossover
    if (_containsAny(m, ['tucson','santa fe','kona','creta','ix35','ix55','tucson','palisade','venue','ioniq','nexo','discovery','freelander','evoque','sport','defender','wrangler','commander','compass','renegade','cherokee','grand cherokee','pathfinder','x-trail','qashqai','juke','murano','armada','outlander','eclipse cross','pajero','asx','cx-3','cx-5','cx-7','cx-9','rav4','c-hr','land cruiser','highlander','4runner','sequoia','fj','kaşkai','qashqai','arkana','kadjar','captur','clio crossover','duster','jogger','sandero stepway','300x','koleos','koleos','tiguan','touareg','t-roc','t-cross','taos','id.4','atlas','macan','cayenne','terracan','ioniq','pulse'])) {
      return Icons.directions_car_filled_rounded; // SUV
    }
    // Sedan default
    return Icons.directions_car_rounded;
  }

  static bool _containsAny(String text, List<String> keywords) {
    for (final k in keywords) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  /// Araç tipine göre renk
  static Color getColor(String vehicleType) {
    switch (vehicleType) {
      case 'Traktör': return const Color(0xFF4CAF50);
      case 'Biçerdöver': return const Color(0xFFFF9800);
      case 'Kamyon': return const Color(0xFF2196F3);
      case 'Araç': return const Color(0xFF9C27B0);
      case 'Jeneratör': return const Color(0xFFFFEB3B);
      case 'İş Makinesi':
      case 'İş Makinası': return const Color(0xFFFF5722);
      case 'Sulama Pompası': return const Color(0xFF00BCD4);
      default: return const Color(0xFF607D8B);
    }
  }
}
