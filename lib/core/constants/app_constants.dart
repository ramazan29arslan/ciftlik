class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Çiftlik Yönetim';
  static const String appVersion = '1.0.0';

  // Supabase
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Storage Buckets
  static const String animalsBucket = 'animals';
  static const String vehiclesBucket = 'vehicles';
  static const String documentsBucket = 'documents';
  static const String buildingsBucket = 'buildings';

  // Hive Boxes
  static const String animalsBox = 'animals_box';
  static const String vehiclesBox = 'vehicles_box';
  static const String buildingsBox = 'buildings_box';
  static const String stockBox = 'stock_box';
  static const String settingsBox = 'settings_box';
  static const String notificationsBox = 'notifications_box';

  // Pagination
  static const int pageSize = 20;

  // Energy
  static const double defaultElectricityRate = 3.5; // TL per kWh

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleManager = 'manager';
  static const String roleWorker = 'worker';
  static const String roleVet = 'vet';

  // Animal Types
  static const List<String> animalTypes = [
    'Sığır', 'Koyun', 'Keçi', 'At', 'Domuz', 'Manda', 'Deve',
    'Tavuk', 'Hindi', 'Ördek', 'Kaz',
    'Kedi', 'Köpek', 'Diğer'
  ];

  // Vehicle Types
  static const List<String> vehicleTypes = [
    'Traktör', 'Biçerdöver', 'Kamyon', 'Kamyonet',
    'Jeneratör', 'İş Makinesi', 'Sulama Pompası', 'Diğer'
  ];

  // Building Types
  static const List<String> buildingTypes = [
    'Ev', 'Ahır', 'Samanlık', 'Depo', 'Sağımhane',
    'Atölye', 'Kümes', 'Sera', 'Diğer'
  ];

  // Stock Categories
  static const List<String> stockCategories = [
    'Yem', 'Saman', 'İlaç', 'Ekipman', 'Yedek Parça',
    'Gübre', 'Tohum', 'Yakıt', 'Diğer'
  ];

  // Maintenance Types
  static const List<String> maintenanceTypes = [
    'Yağ Değişimi', 'Filtre Değişimi', 'Lastik Değişimi',
    'Genel Bakım', 'Arıza Onarımı', 'Periyodik Bakım', 'Diğer'
  ];

  // Document Categories
  static const List<String> documentCategories = [
    'Ruhsat', 'Sigorta', 'Muayene', 'Kasko',
    'Veteriner Raporu', 'Fatura', 'Sözleşme', 'Diğer'
  ];
}
