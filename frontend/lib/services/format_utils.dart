import 'package:intl/intl.dart';

class FormatUtils {
  static String formatPlaytime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m playtime';
    } else {
      return '${minutes}m playtime';
    }
  }

  static String formatCompactPlaytime(int seconds) {
    int hours = seconds ~/ 3600;
    if (hours > 0) {
      return '${hours}h';
    }
    int minutes = (seconds % 3600) ~/ 60;
    return '${minutes}m';
  }

  static String formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('MMM yyyy').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }
}
