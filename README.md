# 🌾 Çiftlik Yönetim Sistemi

Modern, mobil öncelikli çiftlik yönetim uygulaması. Flutter + Supabase ile geliştirilmiştir.

## 📱 Özellikler

| Modül | Özellikler |
|-------|-----------|
| 🐄 Hayvan Yönetimi | Küpe takibi, aşı, süt verimi, gebelik |
| 🚜 Araç & Makineler | Yakıt, bakım, evrak, zaman tüneli |
| 🏠 Yapılar | Ahır, depo, enerji tüketimi |
| ⚡ Enerji | Cihaz bazlı hesaplama, fatura tahmini |
| 📦 Stok | Giriş/çıkış, düşük stok uyarısı |
| 📄 Evraklar | PDF/fotoğraf yükleme, son kullanma takibi |
| 🔔 Bildirimler | Push + uygulama içi bildirimler |
| 📊 Raporlar | Gider, enerji, hayvan, araç raporları |
| 🕐 Zaman Tüneli | Her varlık için kronolojik geçmiş |

## 🏗️ Mimari

```
lib/
├── core/
│   ├── constants/      # Sabitler
│   ├── theme/          # Tema, renkler, yazı stilleri
│   ├── router/         # GoRouter navigasyon
│   ├── utils/          # Tarih, para birimi yardımcıları
│   ├── errors/         # Hata tipleri
│   ├── network/        # Supabase servisi
│   └── di/             # Dependency injection (Riverpod)
│
├── features/
│   ├── auth/           # Giriş, splash
│   ├── dashboard/      # Ana sayfa
│   ├── animals/        # Hayvan yönetimi
│   ├── vehicles/       # Araç yönetimi
│   ├── buildings/      # Yapı yönetimi
│   ├── devices/        # Cihaz yönetimi
│   ├── energy/         # Enerji hesaplama
│   ├── stock/          # Stok yönetimi
│   ├── documents/      # Evrak yönetimi
│   ├── notifications/  # Bildirimler
│   ├── reports/        # Raporlar
│   ├── timeline/       # Zaman tüneli
│   └── expenses/       # Giderler
│
└── shared/
    ├── widgets/        # Ortak widget'lar
    ├── models/         # Ortak modeller
    └── utils/          # Ortak yardımcılar
```

Her feature klasörü Clean Architecture'a göre:
```
feature/
├── data/
│   ├── datasources/    # Supabase / local
│   ├── models/         # JSON serialization
│   └── repositories/   # Repository implementasyonu
├── domain/
│   ├── entities/       # Pure Dart sınıfları
│   ├── repositories/   # Abstract repository
│   └── usecases/       # İş mantığı
└── presentation/
    ├── pages/          # Ekranlar
    ├── widgets/        # Feature-specific widget'lar
    └── providers/      # Riverpod providers
```

## 🚀 Kurulum

### 1. Gereksinimler
- Flutter 3.x+
- Dart 3.x+
- Supabase hesabı
- Firebase projesi (bildirimler için)

### 2. Supabase Kurulumu

1. [supabase.com](https://supabase.com) üzerinde yeni proje oluşturun
2. `supabase/schema.sql` dosyasını SQL Editor'da çalıştırın
3. Storage'da bucket'lar oluşturun:
   - `animals`
   - `vehicles`
   - `documents`
   - `buildings`

### 3. Firebase Kurulumu

1. Firebase Console'da proje oluşturun
2. Android ve iOS uygulamalarını ekleyin
3. `google-services.json` ve `GoogleService-Info.plist` dosyalarını indirin
4. FCM'i etkinleştirin

### 4. Konfigürasyon

`lib/core/constants/app_constants.dart` dosyasını güncelleyin:

```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 5. Bağımlılıkları Yükle

```bash
flutter pub get
```

### 6. Çalıştır

```bash
flutter run
```

## 🎨 Tasarım Sistemi

### Renkler
- **Primary**: `#1B5E20` (Koyu Yeşil)
- **Background**: `#F5F7F5`
- **Surface**: `#FFFFFF`
- **Text Primary**: `#1A1A1A`

### Tipografi
- Font: **Inter**
- Ağırlıklar: 400, 500, 600, 700

### Bileşenler
- `AppCard` — Kart bileşeni
- `AppButton` — Buton bileşeni
- `AppBadge` — Etiket bileşeni
- `AppSearchBar` — Arama çubuğu
- `AppEmptyState` — Boş durum
- `AppLoadingState` — Yükleme durumu
- `AppErrorState` — Hata durumu
- `TimelineWidget` — Zaman tüneli

## 🗄️ Veritabanı Şeması

### Ana Tablolar
| Tablo | Açıklama |
|-------|---------|
| `farms` | Çiftlik bilgileri |
| `farm_members` | Kullanıcı rolleri |
| `animals` | Hayvan kayıtları |
| `animal_vaccinations` | Aşı kayıtları |
| `milk_records` | Süt verimi |
| `vehicles` | Araç kayıtları |
| `fuel_records` | Yakıt kayıtları |
| `maintenance_records` | Bakım kayıtları |
| `buildings` | Yapı kayıtları |
| `devices` | Cihaz kayıtları |
| `stock_items` | Stok kalemleri |
| `stock_movements` | Stok hareketleri |
| `expenses` | Gider kayıtları |
| `documents` | Evrak kayıtları |
| `notifications` | Bildirimler |
| `timeline_events` | Zaman tüneli |

## 👥 Roller

| Rol | Yetki |
|-----|-------|
| `admin` | Tam yetki |
| `manager` | Yönetici (silme hariç) |
| `worker` | Kayıt ekleme/görüntüleme |
| `vet` | Sağlık kayıtları |

## 📊 Enerji Hesaplama

```
Günlük tüketim = (Watt / 1000) × Günlük kullanım saati
Aylık tüketim = Günlük tüketim × Çalışma günü
Tahmini fatura = Aylık tüketim × Birim fiyat (₺/kWh)
```

## 🔔 Bildirim Türleri

- `vaccination` — Aşı zamanı
- `insurance` — Sigorta bitiş
- `maintenance` — Bakım zamanı
- `lowStock` — Düşük stok
- `inspection` — Muayene tarihi
- `pregnancy` — Doğum yaklaşıyor

## 📱 Desteklenen Platformlar

- ✅ Android (API 21+)
- ✅ iOS (14+)

## 🔮 Gelecek Özellikler

- [ ] QR/Küpe okutma
- [ ] Barkod sistemi
- [ ] AI destekli analiz
- [ ] IoT sensör entegrasyonu
- [ ] GPS takibi
- [ ] Offline sync (tam)
- [ ] Web desteği

## 📄 Lisans

MIT License
