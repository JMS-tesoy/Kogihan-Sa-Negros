abstract final class DateFormatters {
  static String shortDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
