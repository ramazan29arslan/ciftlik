import 'package:intl/intl.dart';

class CurrencyUtils {
  CurrencyUtils._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormat = NumberFormat.compact(locale: 'tr_TR');

  static final NumberFormat _numberFormat = NumberFormat('#,##0.##', 'tr_TR');

  static String format(double? amount) {
    if (amount == null) return '₺0,00';
    return _currencyFormat.format(amount);
  }

  static String formatCompact(double? amount) {
    if (amount == null) return '₺0';
    if (amount >= 1000000) {
      return '₺${_compactFormat.format(amount)}';
    }
    return format(amount);
  }

  static String formatNumber(double? number) {
    if (number == null) return '0';
    return _numberFormat.format(number);
  }

  static String formatLiters(double? liters) {
    if (liters == null) return '0 L';
    return '${_numberFormat.format(liters)} L';
  }

  static String formatKwh(double? kwh) {
    if (kwh == null) return '0 kWh';
    return '${_numberFormat.format(kwh)} kWh';
  }

  static String formatKm(double? km) {
    if (km == null) return '0 km';
    return '${_numberFormat.format(km)} km';
  }

  static String formatHours(double? hours) {
    if (hours == null) return '0 saat';
    return '${_numberFormat.format(hours)} saat';
  }

  static String formatWeight(double? kg) {
    if (kg == null) return '0 kg';
    if (kg >= 1000) return '${_numberFormat.format(kg / 1000)} ton';
    return '${_numberFormat.format(kg)} kg';
  }
}
