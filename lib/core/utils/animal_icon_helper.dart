import 'package:flutter/material.dart';

class AnimalIconHelper {
  /// Hayvan türüne göre ikon döndürür
  static IconData getIcon(String type) {
    switch (type) {
      case 'Sığır':
      case 'Manda':
        return Icons.ramen_dining_rounded; // placeholder, aşağıda emoji kullanacağız
      case 'Koyun':
      case 'Keçi':
        return Icons.pets_rounded;
      case 'At':
        return Icons.directions_run_rounded;
      case 'Domuz':
        return Icons.pets_rounded;
      case 'Deve':
        return Icons.landscape_rounded;
      case 'Tavuk':
      case 'Hindi':
      case 'Ördek':
      case 'Kaz':
        return Icons.egg_rounded;
      case 'Kedi':
        return Icons.catching_pokemon; // kedi yüzüne benzer
      case 'Köpek':
        return Icons.pets_rounded;
      default:
        return Icons.cruelty_free_rounded;
    }
  }

  /// Hayvan türüne göre emoji döndürür (icon yerine Text widget'ında kullanılır)
  static String getEmoji(String type) {
    switch (type) {
      case 'Sığır': return '🐄';
      case 'Manda': return '🐃';
      case 'Koyun': return '🐑';
      case 'Keçi': return '🐐';
      case 'At': return '🐎';
      case 'Domuz': return '🐷';
      case 'Deve': return '🐪';
      case 'Tavuk': return '🐔';
      case 'Hindi': return '🦃';
      case 'Ördek': return '🦆';
      case 'Kaz': return '🪿';
      case 'Kedi': return '🐱';
      case 'Köpek': return '🐶';
      default: return '🐾';
    }
  }

  /// Hayvan türüne göre renk döndürür
  static Color getColor(String type) {
    switch (type) {
      case 'Sığır':
      case 'Manda': return const Color(0xFF795548);
      case 'Koyun': return const Color(0xFF9E9E9E);
      case 'Keçi': return const Color(0xFF8D6E63);
      case 'At': return const Color(0xFF6D4C41);
      case 'Domuz': return const Color(0xFFE91E63);
      case 'Deve': return const Color(0xFFD4A017);
      case 'Tavuk':
      case 'Hindi':
      case 'Ördek':
      case 'Kaz': return const Color(0xFFFF9800);
      case 'Kedi': return const Color(0xFF9C27B0);
      case 'Köpek': return const Color(0xFF2196F3);
      default: return const Color(0xFF4CAF50);
    }
  }
}
