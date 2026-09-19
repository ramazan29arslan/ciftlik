/// Ekim kaydinda kullanilan urun katalogu.
///
/// Listede olmayan bir urun icin her iki acilir menude de "Diger" secenegi
/// bulunur; kullanici o zaman adi serbest metin olarak girer.
///
/// Yeni urun eklemek icin ilgili listeye bir satir eklemek yeterli — baska
/// hicbir yeri degistirmek gerekmez.
class CropCatalog {
  const CropCatalog._();

  /// Listede olmayani elle girmek icin kullanilan secenek.
  static const other = 'Diğer';

  static const Map<String, List<String>> byCategory = {
    'Tahıl': [
      'Buğday',
      'Arpa',
      'Mısır',
      'Çavdar',
      'Yulaf',
      'Tritikale',
      'Pirinç',
      'Darı',
    ],
    'Baklagil': [
      'Nohut',
      'Mercimek',
      'Fasulye',
      'Bakla',
      'Bezelye',
      'Soya',
    ],
    'Yem Bitkisi': [
      'Yonca',
      'Korunga',
      'Fiğ',
      'Silajlık Mısır',
      'Sorgum',
    ],
    'Endüstri Bitkisi': [
      'Ayçiçeği',
      'Pamuk',
      'Şeker Pancarı',
      'Kanola',
      'Tütün',
      'Susam',
    ],
    'Sebze': [
      'Domates',
      'Biber',
      'Patlıcan',
      'Salatalık',
      'Kabak',
      'Soğan',
      'Sarımsak',
      'Patates',
      'Havuç',
      'Lahana',
      'Marul',
      'Ispanak',
      'Karpuz',
      'Kavun',
    ],
    'Meyve': [
      'Elma',
      'Armut',
      'Kiraz',
      'Vişne',
      'Şeftali',
      'Kayısı',
      'Erik',
      'Üzüm',
      'İncir',
      'Ceviz',
      'Badem',
      'Fındık',
      'Zeytin',
      'Nar',
    ],
  };

  /// Acilir menude gosterilecek kategoriler — en sonda "Diger".
  static List<String> get categories => [...byCategory.keys, other];

  /// Secilen kategorinin urunleri — en sonda "Diger".
  static List<String> productsOf(String? category) {
    final items = byCategory[category];
    if (items == null) return [other];
    return [...items, other];
  }

  /// Bir urun adindan kategorisini bulur. Katalogda yoksa null doner —
  /// cagiran taraf kendi varsayilanini kullanir.
  static String? categoryOf(String productName) {
    final needle = productName.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final entry in byCategory.entries) {
      for (final product in entry.value) {
        if (product.toLowerCase() == needle) return entry.key;
      }
    }
    return null;
  }
}
