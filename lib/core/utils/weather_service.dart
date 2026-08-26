import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

const _savedCityKey = 'saved_weather_city';

class CitySuggestion {
  final String name;
  final String displayName;
  const CitySuggestion({required this.name, required this.displayName});
}

Future<List<CitySuggestion>> fetchCitySuggestions(String query) async {
  if (query.trim().length < 2) return [];
  try {
    final url = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(query.trim())}&count=8&language=tr&format=json');
    final response = await http.get(url).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List? ?? [];
    return results.map((r) {
      final map = r as Map<String, dynamic>;
      final name = map['name'] as String? ?? '';
      final country = map['country'] as String? ?? '';
      final admin1 = map['admin1'] as String? ?? '';
      final display =
          admin1.isNotEmpty ? '$name, $admin1, $country' : '$name, $country';
      return CitySuggestion(name: name, displayName: display);
    }).toList();
  } catch (_) {
    return [];
  }
}

String _emojiForCode(int weatherCode) {
  if (weatherCode == 113) return '☀️';
  if (weatherCode == 116) return '⛅';
  if (weatherCode == 119 || weatherCode == 122) return '☁️';
  if ([143, 248, 260].contains(weatherCode)) return '🌫️';
  if ([176, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 311, 314, 317, 320, 353, 356, 359, 362, 365, 374, 377].contains(weatherCode)) return '🌧️';
  if ([179, 182, 185, 323, 326, 329, 332, 335, 338, 350, 368, 371, 395].contains(weatherCode)) return '❄️';
  if ([200, 386, 389, 392].contains(weatherCode)) return '⛈️';
  return '🌤️';
}

class HourlyForecast {
  final int hour;
  final double temp;
  final int weatherCode;
  final double chanceOfRain;
  final double windSpeedKmph;

  const HourlyForecast({
    required this.hour,
    required this.temp,
    required this.weatherCode,
    required this.chanceOfRain,
    required this.windSpeedKmph,
  });

  String get emoji => _emojiForCode(weatherCode);
  String get timeLabel => '${hour.toString().padLeft(2, '0')}:00';
}

class DayForecast {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final int weatherCode;
  final double chanceOfRain;
  final double windSpeedKmph;
  final List<HourlyForecast> hourly;

  const DayForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.weatherCode,
    required this.chanceOfRain,
    required this.windSpeedKmph,
    required this.hourly,
  });

  String get emoji => _emojiForCode(weatherCode);

  String get dayName {
    const days = ['Paz', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt'];
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Bugün';
    }
    return days[date.weekday % 7];
  }
}

class WeatherData {
  final String city;
  final double temp;
  final String description;
  final int weatherCode;
  final int humidity;
  final double windSpeed;
  final List<DayForecast> forecast;

  const WeatherData({
    required this.city,
    required this.temp,
    required this.description,
    required this.weatherCode,
    required this.humidity,
    required this.windSpeed,
    required this.forecast,
  });

  String get iconEmoji => _emojiForCode(weatherCode);
  String get tempStr => '${temp.round()}°C';
}

class WeatherNotifier extends StateNotifier<AsyncValue<WeatherData?>> {
  WeatherNotifier() : super(const AsyncValue.data(null));

  Future<void> loadWeather() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString(_savedCityKey);
      if (savedCity != null && savedCity.isNotEmpty) {
        await _fetchByCity(savedCity);
      } else {
        await _fetchByLocation();
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// "Konumum" butonundan doğrudan GPS ile çek — kayıtlı şehri yok say
  Future<String?> loadByGPS() async {
    return await _fetchByLocation();
  }

  Future<void> setCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedCityKey, city);
    await _fetchByCity(city);
  }

  Future<void> _fetchByCity(String city) async {
    try {
      state = const AsyncValue.loading();
      final encoded = Uri.encodeComponent(city);
      final url = Uri.parse('https://wttr.in/$encoded?format=j1');
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        state = AsyncValue.data(_parse(response.body, city));
      } else {
        state = AsyncValue.error('Şehir bulunamadı', StackTrace.current);
      }
    } catch (e) {
      state = AsyncValue.error('Bağlantı hatası', StackTrace.current);
    }
  }

  Future<String?> _fetchByLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = const AsyncValue.data(null);
        return 'Konum servisi kapalı. Lütfen GPS\'i açın.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = const AsyncValue.data(null);
          return 'Konum izni verilmedi.';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        // Telefonun ayarlarını açmak için Geolocator.openAppSettings() çağır
        await Geolocator.openAppSettings();
        state = const AsyncValue.data(null);
        return 'Konum izni kalıcı olarak reddedildi. Uygulama ayarlarından izin verin.';
      }

      state = const AsyncValue.loading();
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 15));

      final lat = position.latitude.toStringAsFixed(4);
      final lon = position.longitude.toStringAsFixed(4);
      final url = Uri.parse('https://wttr.in/$lat,$lon?format=j1');
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_savedCityKey, '$lat,$lon');
        state = AsyncValue.data(_parse(response.body, '$lat,$lon'));
        return null; // başarılı
      } else {
        state = const AsyncValue.data(null);
        return 'Hava durumu alınamadı.';
      }
    } catch (e) {
      state = const AsyncValue.data(null);
      return 'Konum alınamadı: ${e.toString()}';
    }
  }

  WeatherData _parse(String body, String fallbackCity) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final current = (json['current_condition'] as List).first as Map<String, dynamic>;

    final temp = double.tryParse(current['temp_C'] as String? ?? '0') ?? 0;
    final humidity = int.tryParse(current['humidity'] as String? ?? '0') ?? 0;
    final windSpeed = double.tryParse(current['windspeedKmph'] as String? ?? '0') ?? 0;
    final weatherCode = int.tryParse(current['weatherCode'] as String? ?? '113') ?? 113;

    final descList = current['lang_tr'] as List?;
    final description = descList != null && descList.isNotEmpty
        ? (descList.first as Map<String, dynamic>)['value'] as String? ?? ''
        : '';

    // Gerçek yer adını API'den al, koordinat gösterme
    final nearest = (json['nearest_area'] as List?)?.firstOrNull as Map<String, dynamic>?;
    final areaName = (nearest?['areaName'] as List?)?.firstOrNull as Map<String, dynamic>?;
    final regionList = nearest?['region'] as List?;
    final region = regionList?.firstOrNull as Map<String, dynamic>?;
    final nearestName = areaName?['value'] as String?;
    final regionName = region?['value'] as String?;
    final cityName = (nearestName != null && nearestName.isNotEmpty)
        ? nearestName
        : (regionName ?? fallbackCity);

    final weatherList = json['weather'] as List? ?? [];
    final forecast = <DayForecast>[];
    final today = DateTime.now();

    for (int i = 0; i < 7; i++) {
      final dayData = weatherList.isNotEmpty
          ? weatherList[i % weatherList.length] as Map<String, dynamic>
          : <String, dynamic>{};

      final maxC = double.tryParse(dayData['maxtempC'] as String? ?? '${temp.round()}') ?? temp;
      final minC = double.tryParse(dayData['mintempC'] as String? ?? '${(temp - 5).round()}') ?? (temp - 5);

      final hourlyRaw = dayData['hourly'] as List?;
      int dayCode = weatherCode;
      double rainChance = 0;
      double dayWind = windSpeed;
      final hourlyList = <HourlyForecast>[];

      if (hourlyRaw != null && hourlyRaw.isNotEmpty) {
        final noon = hourlyRaw.length > 3 ? hourlyRaw[3] : hourlyRaw.first;
        final noonMap = noon as Map<String, dynamic>;
        dayCode = int.tryParse(noonMap['weatherCode'] as String? ?? '$weatherCode') ?? weatherCode;
        rainChance = double.tryParse(noonMap['chanceofrain'] as String? ?? '0') ?? 0;
        dayWind = double.tryParse(noonMap['windspeedKmph'] as String? ?? '$windSpeed') ?? windSpeed;

        for (final h in hourlyRaw) {
          final hMap = h as Map<String, dynamic>;
          final timeStr = hMap['time'] as String? ?? '0';
          final hr = (int.tryParse(timeStr) ?? 0) ~/ 100;
          hourlyList.add(HourlyForecast(
            hour: hr,
            temp: double.tryParse(hMap['tempC'] as String? ?? '0') ?? 0,
            weatherCode: int.tryParse(hMap['weatherCode'] as String? ?? '113') ?? 113,
            chanceOfRain: double.tryParse(hMap['chanceofrain'] as String? ?? '0') ?? 0,
            windSpeedKmph: double.tryParse(hMap['windspeedKmph'] as String? ?? '0') ?? 0,
          ));
        }
      }

      forecast.add(DayForecast(
        date: today.add(Duration(days: i)),
        maxTemp: i == 0 ? temp : maxC,
        minTemp: minC,
        weatherCode: i == 0 ? weatherCode : dayCode,
        chanceOfRain: rainChance,
        windSpeedKmph: i == 0 ? windSpeed : dayWind,
        hourly: hourlyList,
      ));
    }

    return WeatherData(
      city: cityName,
      temp: temp,
      description: description,
      weatherCode: weatherCode,
      humidity: humidity,
      windSpeed: windSpeed,
      forecast: forecast,
    );
  }
}

final weatherProvider =
    StateNotifierProvider<WeatherNotifier, AsyncValue<WeatherData?>>(
  (ref) => WeatherNotifier(),
);
