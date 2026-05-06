import 'package:intl/intl.dart';

class AppFormatters {
  /// Formats a DateTime to a human-readable string: "1 September, 10:30 PM"
  static String formatFullDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    // Using 'd MMMM, h:mm a' for "1 September, 10:30 PM"
    return DateFormat('d MMMM, h:mm:ss a').format(dateTime.toLocal());
  }

  /// Formats a DateTime to just time: "10:30:15 PM"
  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('h:mm:ss a').format(dateTime.toLocal());
  }

  /// Formats a DateTime to just date: "1 September"
  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('d MMMM').format(dateTime.toLocal());
  }
}
