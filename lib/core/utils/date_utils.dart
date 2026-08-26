import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy', 'tr_TR');
  static final DateFormat _dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'tr_TR');
  static final DateFormat _shortMonthFormat = DateFormat('MMM', 'tr_TR');
  static final DateFormat _dayMonthFormat = DateFormat('dd MMM', 'tr_TR');
  static final DateFormat _isoFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    return _dateFormat.format(date);
  }

  static String formatDateTime(DateTime? date) {
    if (date == null) return '-';
    return _dateTimeFormat.format(date);
  }

  static String formatMonthYear(DateTime? date) {
    if (date == null) return '-';
    return _monthYearFormat.format(date);
  }

  static String formatDayMonth(DateTime? date) {
    if (date == null) return '-';
    return _dayMonthFormat.format(date);
  }

  static String formatShortMonth(DateTime? date) {
    if (date == null) return '-';
    return _shortMonthFormat.format(date);
  }

  static String formatRelative(DateTime? date) {
    if (date == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Az önce';
        return '${diff.inMinutes} dakika önce';
      }
      return '${diff.inHours} saat önce';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} hafta önce';
    } else if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} ay önce';
    } else {
      return '${(diff.inDays / 365).floor()} yıl önce';
    }
  }

  static String formatDaysUntil(DateTime? date) {
    if (date == null) return '-';
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.isNegative) {
      return '${diff.inDays.abs()} gün geçti';
    } else if (diff.inDays == 0) {
      return 'Bugün';
    } else if (diff.inDays == 1) {
      return 'Yarın';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün kaldı';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} hafta kaldı';
    } else {
      return '${(diff.inDays / 30).floor()} ay kaldı';
    }
  }

  static bool isExpiringSoon(DateTime? date, {int daysThreshold = 30}) {
    if (date == null) return false;
    final now = DateTime.now();
    final diff = date.difference(now);
    return diff.inDays >= 0 && diff.inDays <= daysThreshold;
  }

  static bool isExpired(DateTime? date) {
    if (date == null) return false;
    return date.isBefore(DateTime.now());
  }

  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  static String toIso(DateTime date) => _isoFormat.format(date);

  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static String formatAge(DateTime birthDate) {
    final now = DateTime.now();
    final diff = now.difference(birthDate);
    final days = diff.inDays;

    if (days < 30) return '$days gün';
    if (days < 365) return '${(days / 30).floor()} ay';
    final years = (days / 365).floor();
    final months = ((days % 365) / 30).floor();
    if (months == 0) return '$years yaş';
    return '$years yaş $months ay';
  }
}
